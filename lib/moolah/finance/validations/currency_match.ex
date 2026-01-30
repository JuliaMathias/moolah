defmodule Moolah.Finance.Validations.CurrencyMatch do
  @moduledoc """
  Validates that transaction and source amounts match the currencies of their respective accounts.

  This validation handles:
  1. Debit/Credit transactions: Amount currency must match the account currency.
  2. Simple Transfers: Amount currency must match both source and target account currencies.
  3. Multi-Currency Transfers: Source amount currency must match source account,
     and transaction amount currency must match target account.
  """

  use Ash.Resource.Validation

  alias Ash.Changeset

  @impl true
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    transaction_type = Changeset.get_attribute(changeset, :transaction_type)
    amount = Changeset.get_attribute(changeset, :amount)
    source_amount = Changeset.get_attribute(changeset, :source_amount)
    account_id = Changeset.get_attribute(changeset, :account_id)
    target_account_id = Changeset.get_attribute(changeset, :target_account_id)

    case fetch_accounts(account_id, target_account_id) do
      {:ok, account, target_account} ->
        do_validate(transaction_type, amount, source_amount, account, target_account)

      {:error, _error} ->
        # If we can't find accounts, we let other validations (like relational existence) handle it
        # or we could return an error here. However, usually we assume IDs are valid for this check.
        :ok
    end
  end

  @spec fetch_accounts(Ecto.UUID.t(), Ecto.UUID.t() | nil) ::
          {:ok, Ash.Resource.record(), Ash.Resource.record() | nil} | {:error, any()}
  defp fetch_accounts(account_id, target_account_id) do
    with {:ok, account} when not is_nil(account) <- Ash.get(Moolah.Ledger.Account, account_id),
         {:ok, target_account} <- fetch_target_account(target_account_id) do
      {:ok, account, target_account}
    else
      {:ok, nil} -> {:error, :account_not_found}
      {:error, error} -> {:error, error}
    end
  end

  @spec fetch_target_account(Ecto.UUID.t() | nil) ::
          {:ok, Ash.Resource.record() | nil} | {:error, any()}
  defp fetch_target_account(nil), do: {:ok, nil}
  defp fetch_target_account(id), do: Ash.get(Moolah.Ledger.Account, id)

  defp do_validate(:debit, amount, _, account, _) do
    check_match(amount, account, :account_id)
  end

  defp do_validate(:credit, amount, _, account, _) do
    check_match(amount, account, :account_id)
  end

  defp do_validate(:transfer, amount, source_amount, account, target_account) do
    # Detection logic similar to CreateUnderlyingTransfer
    multi_currency? = source_amount && source_amount.currency != amount.currency

    cond do
      source_amount && source_amount.currency == amount.currency ->
        {:error,
         field: :source_amount,
         message:
           "must be nil for single-currency transfers (it matches the amount automatically)"}

      multi_currency? ->
        with :ok <- check_match(source_amount, account, :account_id) do
          check_match(amount, target_account, :target_account_id)
        end

      true ->
        # Simple transfer (or source_amount is nil)
        with :ok <- check_match(amount, account, :account_id) do
          check_match(amount, target_account, :target_account_id)
        end
    end
  end

  defp do_validate(_, _, _, _, _), do: :ok

  defp check_match(nil, _, _), do: :ok
  defp check_match(_, nil, _), do: :ok

  defp check_match(%Money{} = money, %{currency: currency}, field) do
    if to_string(money.currency) == to_string(currency) do
      :ok
    else
      {:error,
       field: field,
       message:
         "currency #{money.currency} does not match account currency #{currency} for #{field}"}
    end
  end
end

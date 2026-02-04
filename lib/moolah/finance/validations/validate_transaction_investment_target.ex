defmodule Moolah.Finance.Validations.ValidateTransactionInvestmentTarget do
  @moduledoc """
  Validates that transfer transactions target a valid investment when an investment
  account is involved.

  This validation enforces three behaviors:

  1. `target_investment_id` is only allowed for `:transfer` transactions.
  2. If a transfer involves an investment account, `target_investment_id` is required.
  3. The selected investment must belong to the investment account involved in the transfer.

  When account or investment lookups fail, the validation returns `:ok` so relationship
  validations can handle missing data.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.Transaction
      ...>   |> Ash.Changeset.for_create(:create, %{
      ...>     transaction_type: :transfer,
      ...>     account_id: account_id,
      ...>     target_account_id: investment_account_id,
      ...>     target_investment_id: investment_id
      ...>   })
      iex> Moolah.Finance.Validations.ValidateTransactionInvestmentTarget.validate(changeset, [], %{})
      :ok
  """

  use Ash.Resource.Validation

  alias Ash.Changeset
  alias Moolah.Finance.Investment
  alias Moolah.Ledger.Account

  @impl true
  @doc """
  Ensures investment targets are only set when appropriate and match the correct account.
  """
  @spec validate(Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    transaction_type =
      Changeset.get_attribute(changeset, :transaction_type) || changeset.data.transaction_type

    target_investment_id =
      Changeset.get_attribute(changeset, :target_investment_id) ||
        changeset.data.target_investment_id

    account_id = Changeset.get_attribute(changeset, :account_id) || changeset.data.account_id

    target_account_id =
      Changeset.get_attribute(changeset, :target_account_id) || changeset.data.target_account_id

    cond do
      transaction_type != :transfer and not is_nil(target_investment_id) ->
        {:error,
         field: :target_investment_id, message: "can only be set for transfer transactions"}

      transaction_type != :transfer ->
        :ok

      true ->
        validate_transfer_target(account_id, target_account_id, target_investment_id)
    end
  end

  @spec validate_transfer_target(Ecto.UUID.t() | nil, Ecto.UUID.t() | nil, Ecto.UUID.t() | nil) ::
          :ok | {:error, keyword()}
  defp validate_transfer_target(account_id, target_account_id, target_investment_id) do
    case investment_involvement(account_id, target_account_id) do
      :none ->
        validate_non_investment_transfer(target_investment_id)

      {:investment, expected_account_id} ->
        validate_investment_selection(expected_account_id, target_investment_id)
    end
  end

  @spec investment_involvement(Ecto.UUID.t() | nil, Ecto.UUID.t() | nil) ::
          :none | {:investment, Ecto.UUID.t()}
  defp investment_involvement(account_id, target_account_id) do
    source_is_investment = investment_account?(account_id)
    target_is_investment = investment_account?(target_account_id)

    cond do
      target_is_investment -> {:investment, target_account_id}
      source_is_investment -> {:investment, account_id}
      true -> :none
    end
  end

  @spec validate_non_investment_transfer(Ecto.UUID.t() | nil) :: :ok | {:error, keyword()}
  defp validate_non_investment_transfer(nil), do: :ok

  defp validate_non_investment_transfer(_target_investment_id) do
    {:error, field: :target_investment_id, message: "only allowed for investment transfers"}
  end

  @spec validate_investment_selection(Ecto.UUID.t(), Ecto.UUID.t() | nil) ::
          :ok | {:error, keyword()}
  defp validate_investment_selection(_expected_account_id, nil) do
    {:error, field: :target_investment_id, message: "is required for investment transfers"}
  end

  defp validate_investment_selection(expected_account_id, target_investment_id) do
    case Ash.get(Investment, target_investment_id) do
      {:ok, %Investment{account_id: ^expected_account_id}} ->
        :ok

      {:ok, %Investment{}} ->
        {:error,
         field: :target_investment_id,
         message: "must belong to the investment account involved in the transfer"}

      _ ->
        :ok
    end
  end

  @spec investment_account?(Ecto.UUID.t() | nil) :: boolean()
  defp investment_account?(nil), do: false

  defp investment_account?(account_id) do
    case Ash.get(Account, account_id) do
      {:ok, %{account_type: :investment_account}} -> true
      _ -> false
    end
  end
end

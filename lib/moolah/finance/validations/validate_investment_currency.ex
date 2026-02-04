defmodule Moolah.Finance.Validations.ValidateInvestmentCurrency do
  @moduledoc """
  Validates that investment money fields match the currency of the linked account.

  This validation enforces three rules:

  1. `initial_value` must be in the same currency as the linked ledger account.
  2. `current_value` must be in the same currency as the linked ledger account.
  3. `initial_value` and `current_value` must share the same currency.

  If account lookup fails, the validation returns `:ok` and lets relationship
  validations handle the missing or invalid account.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.Investment
      ...>   |> Ash.Changeset.for_create(:create, %{
      ...>     account_id: account_id,
      ...>     initial_value: Money.new(100, :BRL),
      ...>     current_value: Money.new(120, :BRL)
      ...>   })
      iex> Moolah.Finance.Validations.ValidateInvestmentCurrency.validate(changeset, [], %{})
      :ok
  """

  use Ash.Resource.Validation

  alias Ash.Changeset
  alias Moolah.Ledger.Account

  @impl true
  @doc """
  Validates that investment money fields match the linked account currency.

  Returns `:ok` when currencies align or when the account cannot be loaded.
  Returns `{:error, field: ..., message: ...}` for the first currency mismatch.
  """
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    account_id = Changeset.get_attribute(changeset, :account_id) || changeset.data.account_id

    initial_value =
      Changeset.get_attribute(changeset, :initial_value) || changeset.data.initial_value

    current_value =
      Changeset.get_attribute(changeset, :current_value) || changeset.data.current_value

    with {:ok, account} when not is_nil(account) <- Ash.get(Account, account_id),
         {:ok, initial_currency} <- get_currency(initial_value),
         {:ok, current_currency} <- get_currency(current_value) do
      cond do
        to_string(account.currency) != to_string(initial_currency) ->
          {:error,
           field: :initial_value,
           message: "currency must match account currency (#{account.currency})"}

        to_string(account.currency) != to_string(current_currency) ->
          {:error,
           field: :current_value,
           message: "currency must match account currency (#{account.currency})"}

        to_string(initial_currency) != to_string(current_currency) ->
          {:error, field: :current_value, message: "currency must match initial value currency"}

        true ->
          :ok
      end
    else
      _ -> :ok
    end
  end

  @spec get_currency(Money.t() | term()) :: {:ok, atom()} | {:error, :invalid_money}
  defp get_currency(%Money{currency: currency}), do: {:ok, currency}
  defp get_currency(_), do: {:error, :invalid_money}
end

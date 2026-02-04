defmodule Moolah.Finance.Validations.ValidateInvestmentAccountType do
  @moduledoc """
  Ensures investments link to ledger accounts of type :investment_account.
  """

  use Ash.Resource.Validation

  alias Ash.Changeset
  alias Moolah.Ledger.Account

  @impl true
  @doc """
  Validates that the linked ledger account is an investment account.

  ## Examples

      # Typical usage inside a resource:
      validations do
        validate {Moolah.Finance.Validations.ValidateInvestmentAccountType, []}
      end

      # Direct invocation (for testing/debugging):
      iex> changeset =
      ...>   Moolah.Finance.Investment
      ...>   |> Ash.Changeset.for_create(:create, %{account_id: account_id})
      iex> Moolah.Finance.Validations.ValidateInvestmentAccountType.validate(changeset, [], %{})
      :ok
  """
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    account_id = Changeset.get_attribute(changeset, :account_id) || changeset.data.account_id

    case Ash.get(Account, account_id) do
      {:ok, %{account_type: :investment_account}} ->
        :ok

      {:ok, %{} = _account} ->
        {:error, field: :account_id, message: "must be an investment account"}

      _ ->
        :ok
    end
  end
end

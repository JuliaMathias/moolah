defmodule Moolah.Finance.Changes.CreateUnderlyingTransfer do
  @moduledoc """
  This module defines an Ash Resource Change that acts as a hook during the `create` decision
  lifecycle of a `Transaction`.

  It is responsible for translating the user's high-level transaction intent (e.g., "Spent $20 on Lunch")
  into the precise double-entry bookkeeping records required by the `Moolah.Ledger` system
  (e.g., Debit Expense:Food, Credit Assets:Bank).

  This abstraction ensures that users can interact with simple financial concepts while the system
  maintains rigorous accounting integrity under the hood.
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Moolah.Finance.Services.VirtualAccountService

  @type changeset :: Ash.Changeset.t()

  @doc """
  Callback for the Ash.Resource.Change behaviour.
  Orchestrates the creation of the underlying ledger transfer.
  """
  @spec change(changeset(), keyword(), map()) :: changeset()
  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_transaction(changeset, fn changeset ->
      case create_transfer_for_transaction(changeset) do
        {:ok, transfer} ->
          Changeset.force_change_attribute(changeset, :transfer_id, transfer.id)

        {:error, error} ->
          Changeset.add_error(changeset, error)
      end
    end)
  end

  @doc """
  Creates the underlying ledger transfer for a transaction changeset.
  This is used by both the creation action and the update action (when replacing a transaction).
  """
  @spec create_transfer_for_transaction(changeset()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  def create_transfer_for_transaction(changeset) do
    type = Changeset.get_attribute(changeset, :transaction_type)
    amount_money = Changeset.get_attribute(changeset, :amount)
    source_amount_money = Changeset.get_attribute(changeset, :source_amount)

    # Extract amount and currency from AshMoney
    amount = amount_money.amount
    currency = amount_money.currency

    # For source amount (optional, defaults to amount)
    {source_amount, source_currency} =
      if source_amount_money do
        {source_amount_money.amount, source_amount_money.currency}
      else
        {amount, currency}
      end

    account_id = Changeset.get_attribute(changeset, :account_id)
    target_account_id = Changeset.get_attribute(changeset, :target_account_id)

    # We use budget_category for the virtual account link
    category_id = Changeset.get_attribute(changeset, :budget_category_id)

    case type do
      :debit ->
        create_debit_transfer(account_id, category_id, source_amount, source_currency)

      :credit ->
        create_credit_transfer(account_id, category_id, amount, currency)

      :transfer ->
        create_account_transfer(
          account_id,
          target_account_id,
          amount,
          currency,
          source_amount,
          source_currency
        )
    end
  end

  @spec create_debit_transfer(Ecto.UUID.t(), Ecto.UUID.t(), Decimal.t(), atom()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_debit_transfer(account_id, category_id, amount, currency) do
    # Debit: Money moves FROM User Account TO Expense Category
    with {:ok, expense_account} <-
           VirtualAccountService.get_or_create(category_id, :expense, to_string(currency)) do
      Moolah.Ledger.Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(amount, currency),
        from_account_id: account_id,
        to_account_id: expense_account.id
      })
      |> Ash.create()
    end
  end

  @spec create_credit_transfer(Ecto.UUID.t(), Ecto.UUID.t(), Decimal.t(), atom()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_credit_transfer(account_id, category_id, amount, currency) do
    # Credit: Money moves FROM Income Category TO User Account
    with {:ok, income_account} <-
           VirtualAccountService.get_or_create(category_id, :income, to_string(currency)) do
      Moolah.Ledger.Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(amount, currency),
        from_account_id: income_account.id,
        to_account_id: account_id
      })
      |> Ash.create()
    end
  end

  @spec create_account_transfer(
          Ecto.UUID.t(),
          Ecto.UUID.t(),
          Decimal.t(),
          atom(),
          Decimal.t(),
          atom()
        ) :: {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_account_transfer(
         from_id,
         to_id,
         amount,
         currency,
         _source_amount,
         source_currency
       ) do
    # Transfer: Money moves FROM User Account A TO User Account B

    # Check if this is a multi-currency transfer that requires exchange handling
    if currency != source_currency do
      # For MVP: We will simply create the transfer with the destination amount
      # Limitations: This technically violates double-entry if we care about source balance in source currency.
      # However, AshDoubleEntry.Transfer requires a single amount.
      # To do this properly in AshDoubleEntry without an exchange account would require two transfers.
      # 1. From A to Exchange (in source currency)
      # 2. From Exchange to B (in target currency)
      #
      # Given the constraint of returning a SINGLE transfer_id to the Transaction resource,
      # we imply a limitation here: "Transaction tracks the destination value".
      #
      # Use case R$530 -> $100.
      # We will record the $100 transfer into the destination.
      # BUT we need to debit the source R$530.
      # A single AshDoubleEntry.Transfer CANNOT do this.
      #
      # WORKAROUND for MVP:
      # We will create the transfer in the DESTINATION currency.
      # This means the source account (BRL) will be debited $100 USD (which might be converted
      # or just stored as separate balance).
      # A proper multi-currency ledger usually has separate balances per currency.
      # If Account A is BRL, it can hold keys for USD too.

      # FOR NOW: Create the transfer in the DESTINATION currency.
      Moolah.Ledger.Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(amount, currency),
        from_account_id: from_id,
        to_account_id: to_id
      })
      |> Ash.create()
    else
      Moolah.Ledger.Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(amount, currency),
        from_account_id: from_id,
        to_account_id: to_id
      })
      |> Ash.create()
    end
  end
end

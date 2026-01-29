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

    budget_category_id = Changeset.get_attribute(changeset, :budget_category_id)
    life_area_category_id = Changeset.get_attribute(changeset, :life_area_category_id)

    case type do
      :debit ->
        # Debits use Budget Category for the virtual account
        create_debit_transfer(account_id, budget_category_id, source_amount, source_currency)

      :credit ->
        # Credits use Life Area Category for the virtual account (Income)
        create_credit_transfer(account_id, life_area_category_id, amount, currency)

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
         source_amount,
         source_currency
       ) do
    if currency != source_currency do
      # Multi-currency: Trading Account Pattern
      # Leg 1: User -> Trading (Source Currency)
      # Leg 2: Trading -> User (Target Currency)

      trading_source =
        VirtualAccountService.get_or_create_trading_account!(to_string(source_currency))

      trading_target = VirtualAccountService.get_or_create_trading_account!(to_string(currency))

      # Calculate exchange rate: source / target
      # e.g. 530 / 100 = 5.3
      exchange_rate = Decimal.div(source_amount, amount)

      Moolah.Repo.transaction(fn ->
        with {:ok, s_transfer, s_notifications} <-
               Moolah.Ledger.Transfer
               |> Ash.Changeset.for_create(:transfer, %{
                 amount: Money.new(source_amount, source_currency),
                 from_account_id: from_id,
                 to_account_id: trading_source.id
               })
               |> Ash.create(return_notifications?: true),
             {:ok, t_transfer, t_notifications} <-
               Moolah.Ledger.Transfer
               |> Ash.Changeset.for_create(:transfer, %{
                 amount: Money.new(amount, currency),
                 from_account_id: trading_target.id,
                 to_account_id: to_id
               })
               |> Ash.create(return_notifications?: true) do
          {
            %{
              source_transfer: s_transfer,
              target_transfer: t_transfer,
              exchange_rate: exchange_rate
            },
            s_notifications ++ t_notifications
          }
        else
          {:error, error} -> Moolah.Repo.rollback(error)
        end
      end)
      |> case do
        {:ok, {result, notifications}} -> {:ok, result, notifications}
        {:ok, result} -> {:ok, result, []}
        {:error, error} -> {:error, error}
      end
    else
      # Simple Transfer
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

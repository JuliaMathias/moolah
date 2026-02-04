defmodule Moolah.Finance.InvestmentOperationTransactionTest do
  @moduledoc false

  use Moolah.DataCase, async: false

  alias Moolah.Finance.Investment
  alias Moolah.Finance.InvestmentHistory
  alias Moolah.Finance.InvestmentOperation
  alias Moolah.Finance.Transaction
  alias Moolah.Finance.Validations.ValidateHistoryCurrency
  alias Moolah.Finance.Validations.ValidateOperationCurrency
  alias Moolah.Finance.Validations.ValidateTransactionInvestmentTarget
  alias Moolah.Ledger.Account

  require Ash.Query

  test "transfer into an investment account creates a deposit operation" do
    # Scenario: money moves from a bank account into an investment account.
    # Expected: an InvestmentOperation is created as a :deposit tied to the transaction.
    bank = create_account(%{identifier: unique_id("bank"), account_type: :bank_account})

    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    investment = create_investment(investment_account)

    # Create the transfer transaction with an explicit target investment.
    {:ok, transaction} =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(100, :BRL),
        account_id: bank.id,
        target_account_id: investment_account.id,
        target_investment_id: investment.id,
        date: Date.utc_today()
      })
      |> Ash.create()

    # Load operations tied to the transaction to validate the deposit operation.
    operations =
      InvestmentOperation
      |> Ash.Query.filter(transaction_id: transaction.id)
      |> Ash.read!()

    assert length(operations) == 1
    assert hd(operations).type == :deposit
    assert Money.equal?(hd(operations).value, Money.new(100, :BRL))
  end

  test "transfer out of an investment account creates a withdraw operation" do
    # Scenario: money moves from an investment account into a bank account.
    # Expected: an InvestmentOperation is created as a :withdraw tied to the transaction.
    bank = create_account(%{identifier: unique_id("bank"), account_type: :bank_account})

    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    investment = create_investment(investment_account)

    # Create the transfer transaction with an explicit target investment.
    {:ok, transaction} =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(75, :BRL),
        account_id: investment_account.id,
        target_account_id: bank.id,
        target_investment_id: investment.id,
        date: Date.utc_today()
      })
      |> Ash.create()

    # Load operations tied to the transaction to validate the withdraw operation.
    operations =
      InvestmentOperation
      |> Ash.Query.filter(transaction_id: transaction.id)
      |> Ash.read!()

    assert length(operations) == 1
    assert hd(operations).type == :withdraw
    assert Money.equal?(hd(operations).value, Money.new(75, :BRL))
  end

  test "transfer rejects target_investment_id that belongs to a different account" do
    # Scenario: transfer targets an investment that belongs to a different investment account.
    # Expected: validation rejects the transaction.
    bank = create_account(%{identifier: unique_id("bank"), account_type: :bank_account})

    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    other_investment_account =
      create_account(%{identifier: unique_id("invest-other"), account_type: :investment_account})

    other_investment = create_investment(other_investment_account)

    # Attempt to use a target_investment_id that does not belong to the target account.
    result =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(100, :BRL),
        account_id: bank.id,
        target_account_id: investment_account.id,
        target_investment_id: other_investment.id,
        date: Date.utc_today()
      })
      |> Ash.create()

    assert {:error, %Ash.Error.Invalid{}} = result
  end

  test "transfer between non-investment accounts rejects target_investment_id" do
    # Scenario: a user attempts to attach an investment to a transfer that only
    # involves bank accounts, which should be treated as a plain cash movement.
    # Expected: validation rejects the transaction because no investment account
    # participates in the transfer.
    bank = create_account(%{identifier: unique_id("bank"), account_type: :bank_account})
    other_bank = create_account(%{identifier: unique_id("bank2"), account_type: :bank_account})

    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    investment = create_investment(investment_account)

    result =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(50, :BRL),
        account_id: bank.id,
        target_account_id: other_bank.id,
        target_investment_id: investment.id,
        date: Date.utc_today()
      })
      |> Ash.create()

    assert {:error, %Ash.Error.Invalid{}} = result
  end

  test "transfer into investment account requires target_investment_id" do
    # Scenario: a transfer sends money into an investment account but omits the
    # target investment selection, leaving the system unable to attribute the deposit.
    # Expected: validation rejects the transaction until a target investment is provided.
    bank = create_account(%{identifier: unique_id("bank"), account_type: :bank_account})

    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    result =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(60, :BRL),
        account_id: bank.id,
        target_account_id: investment_account.id,
        date: Date.utc_today()
      })
      |> Ash.create()

    assert {:error, %Ash.Error.Invalid{}} = result
  end

  test "history and operation currency mismatches are rejected" do
    # Scenario: history/operation values use a currency different from the investment currency.
    # Expected: validation rejects the create attempts.
    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    investment = create_investment(investment_account)

    # Try inserting a history entry with a mismatched currency.
    history_result =
      InvestmentHistory
      |> Ash.Changeset.for_create(:create, %{
        investment_id: investment.id,
        recorded_on: Date.utc_today(),
        value: Money.new(10, :USD)
      })
      |> Ash.create()

    assert {:error, %Ash.Error.Invalid{}} = history_result

    # Try inserting an operation with a mismatched currency.
    operation_result =
      InvestmentOperation
      |> Ash.Changeset.for_create(:create, %{
        investment_id: investment.id,
        type: :deposit,
        value: Money.new(10, :USD)
      })
      |> Ash.create()

    assert {:error, %Ash.Error.Invalid{}} = operation_result
  end

  test "currency validations allow invalid money values to fall through" do
    # Scenario: we deliberately inject a non-money value into the changeset to simulate
    # malformed input that should not be handled by currency validations.
    # Expected: the currency validations return :ok so other validations can surface
    # the error without this validation raising or failing first.
    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    investment = create_investment(investment_account)

    history_changeset =
      InvestmentHistory
      |> Ash.Changeset.for_create(:create, %{
        investment_id: investment.id,
        recorded_on: Date.utc_today(),
        value: Money.new(10, :BRL)
      })
      |> Ash.Changeset.force_change_attribute(:value, "oops")

    assert :ok = ValidateHistoryCurrency.validate(history_changeset, [], %{})

    direct_history_changeset =
      InvestmentHistory
      |> Ash.Changeset.for_create(:create, %{
        investment_id: investment.id,
        recorded_on: Date.utc_today(),
        value: "oops"
      })

    assert :ok = ValidateHistoryCurrency.validate(direct_history_changeset, [], %{})

    operation_changeset =
      InvestmentOperation
      |> Ash.Changeset.for_create(:create, %{
        investment_id: investment.id,
        type: :deposit,
        value: Money.new(10, :BRL)
      })
      |> Ash.Changeset.force_change_attribute(:value, "oops")

    assert :ok = ValidateOperationCurrency.validate(operation_changeset, [], %{})

    direct_operation_changeset =
      InvestmentOperation
      |> Ash.Changeset.for_create(:create, %{
        investment_id: investment.id,
        type: :deposit,
        value: "oops"
      })

    assert :ok = ValidateOperationCurrency.validate(direct_operation_changeset, [], %{})
  end

  test "validation skips when target investment lookup fails" do
    # Scenario: a transfer references a target_investment_id that does not exist.
    # Expected: the validation returns :ok so the missing relationship is handled
    # elsewhere (we do not want validation to raise on lookup failures).
    investment_account =
      create_account(%{identifier: unique_id("invest"), account_type: :investment_account})

    changeset =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(10, :BRL),
        account_id: investment_account.id,
        target_account_id: investment_account.id,
        target_investment_id: Ash.UUID.generate(),
        date: Date.utc_today()
      })

    assert :ok = ValidateTransactionInvestmentTarget.validate(changeset, [], %{})
  end

  test "validation skips when accounts are nil" do
    # Scenario: a transfer changeset is built without account ids (nil values),
    # which can happen before relationships are set or when data is incomplete.
    # Expected: validation returns :ok and does not crash, allowing other validations
    # to handle missing fields.
    changeset =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(10, :BRL),
        date: Date.utc_today()
      })

    assert :ok = ValidateTransactionInvestmentTarget.validate(changeset, [], %{})
  end

  @spec create_account(map()) :: Account.t()
  defp create_account(attrs) do
    params =
      %{identifier: unique_id("account"), currency: "BRL", account_type: :bank_account}
      |> Map.merge(attrs)

    Account
    |> Ash.Changeset.for_create(:open, params)
    |> Ash.create!()
  end

  @spec create_investment(Account.t()) :: Investment.t()
  defp create_investment(account) do
    {:ok, investment} =
      Investment
      |> Ash.Changeset.for_create(:create, %{
        name: unique_id("Investment"),
        type: :renda_fixa,
        subtype: :cdb,
        initial_value: Money.new(100, :BRL),
        current_value: Money.new(100, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    investment
  end

  @spec unique_id(String.t()) :: String.t()
  defp unique_id(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"
end

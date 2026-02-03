defmodule Moolah.Finance.InvestmentTest do
  @moduledoc false

  use Moolah.DataCase, async: true

  alias Moolah.Finance.Investment
  alias Moolah.Finance.InvestmentHistory
  alias Moolah.Finance.InvestmentOperation
  alias Moolah.Ledger.Account

  require Ash.Query

  test "creates investment with purchase_date and records history snapshots" do
    # Scenario: a known purchase date should yield two history points (purchase + today).
    account = create_account()

    purchase_date = Date.add(Date.utc_today(), -10)

    {:ok, investment} =
      Investment
      |> Ash.Changeset.for_create(:create, %{
        name: unique_id("Tesouro"),
        type: :tesouro_direto,
        subtype: :selic,
        initial_value: Money.new(1000, :BRL),
        current_value: Money.new(1100, :BRL),
        purchase_date: purchase_date,
        account_id: account.id
      })
      |> Ash.create()

    histories =
      InvestmentHistory
      |> Ash.Query.filter(investment_id: investment.id)
      |> Ash.read!()

    assert Enum.any?(histories, &(&1.recorded_on == purchase_date))
    assert Enum.any?(histories, &(&1.recorded_on == Date.utc_today()))
  end

  test "creates a single history record when purchase_date is missing" do
    # Scenario: without a purchase date, only today's snapshot is recorded.
    account = create_account()

    {:ok, investment} =
      Investment
      |> Ash.Changeset.for_create(:create, %{
        name: unique_id("CDB"),
        type: :renda_fixa,
        subtype: :cdb,
        initial_value: Money.new(500, :BRL),
        current_value: Money.new(500, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    histories =
      InvestmentHistory
      |> Ash.Query.filter(investment_id: investment.id)
      |> Ash.read!()

    assert length(histories) == 1
    assert Enum.any?(histories, &(&1.recorded_on == Date.utc_today()))
  end

  test "updates current_value and records history + operation" do
    # Scenario: a value change should create a new history snapshot and an operation delta.
    account = create_account()

    {:ok, investment} =
      Investment
      |> Ash.Changeset.for_create(:create, %{
        name: unique_id("Fundos"),
        type: :fundos,
        subtype: :multimercado,
        initial_value: Money.new(200, :BRL),
        current_value: Money.new(200, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    {:ok, updated} =
      investment
      |> Ash.Changeset.for_update(:update, %{
        current_value: Money.new(250, :BRL)
      })
      |> Ash.update()

    histories =
      InvestmentHistory
      |> Ash.Query.filter(investment_id: updated.id)
      |> Ash.read!()

    assert Enum.any?(histories, &(&1.recorded_on == Date.utc_today()))

    operations =
      InvestmentOperation
      |> Ash.Query.filter(investment_id: updated.id)
      |> Ash.read!()

    assert length(operations) == 1
    assert hd(operations).type == :update
    assert Money.equal?(hd(operations).value, Money.new(50, :BRL))
  end

  test "rejects invalid subtype for type" do
    account = create_account()

    assert {:error, %Ash.Error.Invalid{}} =
             Investment
             |> Ash.Changeset.for_create(:create, %{
               name: unique_id("Invalid"),
               type: :fundos,
               subtype: :cdb,
               initial_value: Money.new(100, :BRL),
               current_value: Money.new(100, :BRL),
               account_id: account.id
             })
             |> Ash.create()
  end

  test "validates currency against account currency" do
    account = create_account(%{currency: "BRL"})

    assert {:error, %Ash.Error.Invalid{}} =
             Investment
             |> Ash.Changeset.for_create(:create, %{
               name: unique_id("Currency"),
               type: :renda_fixa,
               subtype: :cdb,
               initial_value: Money.new(100, :USD),
               current_value: Money.new(100, :USD),
               account_id: account.id
             })
             |> Ash.create()
  end

  test "rejects non-investment accounts" do
    account = create_account(%{account_type: :bank_account})

    assert {:error, %Ash.Error.Invalid{}} =
             Investment
             |> Ash.Changeset.for_create(:create, %{
               name: unique_id("AccountType"),
               type: :renda_fixa,
               subtype: :cdb,
               initial_value: Money.new(100, :BRL),
               current_value: Money.new(100, :BRL),
               account_id: account.id
             })
             |> Ash.create()
  end

  test "enforces unique investment name" do
    account = create_account()
    name = unique_id("Unique")

    assert {:ok, _investment} =
             Investment
             |> Ash.Changeset.for_create(:create, %{
               name: name,
               type: :renda_variavel,
               subtype: :fiis,
               initial_value: Money.new(100, :BRL),
               current_value: Money.new(100, :BRL),
               account_id: account.id
             })
             |> Ash.create()

    assert {:error, %Ash.Error.Invalid{}} =
             Investment
             |> Ash.Changeset.for_create(:create, %{
               name: name,
               type: :renda_variavel,
               subtype: :fiis,
               initial_value: Money.new(100, :BRL),
               current_value: Money.new(100, :BRL),
               account_id: account.id
             })
             |> Ash.create()
  end

  test "default read filters to active investments" do
    account = create_account()

    {:ok, active} =
      Investment
      |> Ash.Changeset.for_create(:create, %{
        name: unique_id("Active"),
        type: :fundos,
        subtype: :multimercado,
        initial_value: Money.new(100, :BRL),
        current_value: Money.new(100, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    {:ok, expired} =
      Investment
      |> Ash.Changeset.for_create(:create, %{
        name: unique_id("Expired"),
        type: :fundos,
        subtype: :multimercado,
        initial_value: Money.new(100, :BRL),
        current_value: Money.new(100, :BRL),
        redemption_date: Date.add(Date.utc_today(), -1),
        account_id: account.id
      })
      |> Ash.create()

    {:ok, active_results} = Ash.read(Investment)
    assert Enum.any?(active_results, &(&1.id == active.id))
    refute Enum.any?(active_results, &(&1.id == expired.id))

    {:ok, all_results} = Ash.read(Investment, action: :including_expired)
    assert Enum.any?(all_results, &(&1.id == active.id))
    assert Enum.any?(all_results, &(&1.id == expired.id))
  end

  @spec create_account(map()) :: Account.t()
  defp create_account(attrs \\ %{}) do
    params =
      %{
        identifier: unique_id("investment_account"),
        currency: "BRL",
        account_type: :investment_account
      }
      |> Map.merge(attrs)

    Account
    |> Ash.Changeset.for_create(:open, params)
    |> Ash.create!()
  end

  @spec unique_id(String.t()) :: String.t()
  defp unique_id(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"
end

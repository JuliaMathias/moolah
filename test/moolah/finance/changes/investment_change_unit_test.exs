defmodule Moolah.Finance.Changes.InvestmentChangeUnitTest do
  @moduledoc false

  use Moolah.DataCase, async: true

  alias Ash.Changeset
  alias Moolah.Finance.Changes.CreateInvestmentHistory
  alias Moolah.Finance.Changes.TrackInvestmentOperation
  alias Moolah.Finance.Investment
  alias Moolah.Finance.InvestmentOperation
  alias Moolah.Ledger.Account

  require Ash.Query

  test "create history change ignores unknown mode" do
    # Scenario: unsupported mode should return the record unchanged.
    # The change module only handles :create and :update; any other mode should
    # register an after_action that becomes a no-op (it returns the record).
    # This guards against accidental misconfiguration in the resource action.
    account = create_account()

    {:ok, record} =
      Investment
      |> Changeset.for_create(:create, %{
        name: unique_id("UnknownMode"),
        type: :renda_fixa,
        subtype: :cdb,
        initial_value: Money.new(10, :BRL),
        current_value: Money.new(10, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    # Build a changeset that uses an unknown mode. The change should still
    # return a valid changeset without raising or altering the record.
    changeset =
      Investment
      |> Changeset.for_create(:create, %{
        name: unique_id("IgnoreMode"),
        type: :renda_fixa,
        subtype: :cdb,
        initial_value: Money.new(10, :BRL),
        current_value: Money.new(10, :BRL),
        account_id: account.id
      })
      |> CreateInvestmentHistory.change([mode: :noop], %{})

    # Run the after_action hook and assert that the record is returned as-is.
    {:ok, result, _changeset, _meta} = Changeset.run_after_actions(record, changeset, [])

    assert result == record
  end

  test "create history change surfaces insert errors" do
    # Scenario: a history insert should fail when the investment_id does not exist.
    account = create_account()

    changeset =
      Investment
      |> Changeset.for_create(:create, %{
        name: unique_id("MissingInvestment"),
        type: :renda_fixa,
        subtype: :cdb,
        initial_value: Money.new(10, :BRL),
        current_value: Money.new(10, :BRL),
        account_id: account.id
      })
      |> CreateInvestmentHistory.change([mode: :create], %{})

    fake_record = %Investment{
      id: Ash.UUID.generate(),
      purchase_date: nil,
      initial_value: Money.new(10, :BRL),
      current_value: Money.new(10, :BRL)
    }

    assert {:error, _} = Changeset.run_after_actions(fake_record, changeset, [])
  end

  test "track operation change does nothing when current_value is not changing" do
    # Scenario: update changeset without a current_value change should skip operation tracking.
    account = create_account()

    {:ok, investment} =
      Investment
      |> Changeset.for_create(:create, %{
        name: unique_id("NoChangeOperation"),
        type: :fundos,
        subtype: :multimercado,
        initial_value: Money.new(10, :BRL),
        current_value: Money.new(10, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    base_changeset = Changeset.for_update(investment, :update, %{name: "Renamed"})
    base_after_actions = base_changeset.after_action

    changeset = TrackInvestmentOperation.change(base_changeset, [], %{})

    assert changeset.after_action == base_after_actions
  end

  test "track operation change surfaces money subtraction errors" do
    # Scenario: mismatched currencies should bubble up the subtraction error.
    account = create_account()

    {:ok, investment} =
      Investment
      |> Changeset.for_create(:create, %{
        name: unique_id("OperationInsertError"),
        type: :fundos,
        subtype: :multimercado,
        initial_value: Money.new(10, :BRL),
        current_value: Money.new(10, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    changeset =
      investment
      |> Changeset.for_update(:update, %{current_value: Money.new(12, :BRL)})
      |> TrackInvestmentOperation.change([], %{})

    fake_record = %Investment{id: investment.id, current_value: Money.new(12, :USD)}

    assert {:error, _} = Changeset.run_after_actions(fake_record, changeset, [])
  end

  test "track operation change emits update when delta is zero" do
    # Scenario: the change pipeline forces a current_value write with a value that
    # is numerically identical but encoded with different precision (10 vs 10.00).
    # Expected: we still record an :update operation with a zero delta.
    account = create_account()

    {:ok, investment} =
      Investment
      |> Changeset.for_create(:create, %{
        name: unique_id("ZeroDelta"),
        type: :fundos,
        subtype: :multimercado,
        initial_value: Money.new(10, :BRL),
        current_value: Money.new(10, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    changeset =
      investment
      |> Changeset.for_update(:update, %{})
      |> Changeset.force_change_attribute(:current_value, Money.new("10.00", :BRL))
      |> TrackInvestmentOperation.change([], %{})

    record = %Investment{id: investment.id, current_value: Money.new("10.00", :BRL)}

    assert {:ok, _record, _changeset, _meta} = Changeset.run_after_actions(record, changeset, [])

    operations =
      InvestmentOperation
      |> Ash.Query.filter(investment_id: investment.id)
      |> Ash.read!()

    assert length(operations) == 1
    assert hd(operations).type == :update
    assert Money.equal?(hd(operations).value, Money.new(0, :BRL))
  end

  test "track operation change surfaces insert errors" do
    # Scenario: the change reaches the insert step, but we supply a record without
    # an investment id to simulate a broken persistence layer.
    # Expected: the insert failure bubbles up so callers can see the error.
    account = create_account()

    {:ok, investment} =
      Investment
      |> Changeset.for_create(:create, %{
        name: unique_id("MissingId"),
        type: :fundos,
        subtype: :multimercado,
        initial_value: Money.new(10, :BRL),
        current_value: Money.new(10, :BRL),
        account_id: account.id
      })
      |> Ash.create()

    changeset =
      investment
      |> Changeset.for_update(:update, %{current_value: Money.new(12, :BRL)})
      |> TrackInvestmentOperation.change([], %{})

    record = %Investment{id: nil, current_value: Money.new(12, :BRL)}

    assert {:error, _} = Changeset.run_after_actions(record, changeset, [])
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
    |> Changeset.for_create(:open, params)
    |> Ash.create!()
  end

  @spec unique_id(String.t()) :: String.t()
  defp unique_id(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"
end

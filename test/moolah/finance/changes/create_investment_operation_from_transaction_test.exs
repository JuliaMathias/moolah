defmodule Moolah.Finance.Changes.CreateInvestmentOperationFromTransactionTest do
  @moduledoc false

  use Moolah.DataCase, async: false

  alias Ash.Changeset
  alias Moolah.Finance.Changes.CreateInvestmentOperationFromTransaction
  alias Moolah.Finance.Transaction
  alias Moolah.Ledger.Account

  test "returns ok when transfer has nil accounts and no target investment" do
    # Scenario: a transfer is persisted before account relationships are populated,
    # which can happen in async pipelines or partial data ingestion.
    # Expected: the change should interpret this as non-investment and return :ok
    # rather than attempting to resolve accounts or create operations.
    changeset =
      Transaction
      |> Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(10, :BRL),
        date: Date.utc_today()
      })
      |> CreateInvestmentOperationFromTransaction.change([], %{})

    record = %Transaction{
      id: Ash.UUID.generate(),
      transaction_type: :transfer,
      account_id: nil,
      target_account_id: nil,
      target_investment_id: nil,
      amount: Money.new(10, :BRL),
      source_amount: nil
    }

    assert {:ok, _record, _changeset, _meta} = Changeset.run_after_actions(record, changeset, [])
  end

  test "surfaces insert errors when operation creation fails" do
    # Scenario: the transfer indicates an investment account and supplies a target
    # investment id that does not exist, so the operation insert will fail on FK.
    # Expected: the error from the failed insert is surfaced back to the caller.
    investment_account =
      Account
      |> Changeset.for_create(:open, %{
        identifier: "investment-account",
        currency: "BRL",
        account_type: :investment_account
      })
      |> Ash.create!()

    changeset =
      Transaction
      |> Changeset.for_create(:create, %{
        transaction_type: :transfer,
        amount: Money.new(10, :BRL),
        account_id: investment_account.id,
        target_account_id: investment_account.id,
        target_investment_id: Ash.UUID.generate(),
        date: Date.utc_today()
      })
      |> CreateInvestmentOperationFromTransaction.change([], %{})

    record = %Transaction{
      id: Ash.UUID.generate(),
      transaction_type: :transfer,
      account_id: investment_account.id,
      target_account_id: investment_account.id,
      target_investment_id: Ash.UUID.generate(),
      amount: Money.new(10, :BRL),
      source_amount: nil
    }

    assert {:error, _} = Changeset.run_after_actions(record, changeset, [])
  end
end

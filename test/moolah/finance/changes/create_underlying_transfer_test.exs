defmodule Moolah.Finance.Changes.CreateUnderlyingTransferTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.Changes.CreateUnderlyingTransfer
  alias Moolah.Finance.Transaction
  alias Moolah.Ledger.Account

  describe "create_transfer_for_transaction/1" do
    setup do
      # Create test accounts
      bank =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "test_bank",
          currency: "BRL",
          account_type: :bank_account
        })
        |> Ash.create!()

      cash =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "test_cash",
          currency: "BRL",
          account_type: :bank_account
        })
        |> Ash.create!()

      usd_account =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "test_usd",
          currency: "USD",
          account_type: :bank_account
        })
        |> Ash.create!()

      {:ok, bank: bank, cash: cash, usd_account: usd_account}
    end

    test "returns error when amount is nil", %{bank: bank} do
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: bank.id,
          amount: nil,
          date: Date.utc_today()
        })

      result = CreateUnderlyingTransfer.create_transfer_for_transaction(changeset)

      assert {:error, "Transaction amount and date are required"} = result
    end

    test "returns error when date is nil", %{bank: bank} do
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: bank.id,
          amount: Money.new(100, :BRL),
          date: nil
        })

      result = CreateUnderlyingTransfer.create_transfer_for_transaction(changeset)

      assert {:error, "Transaction amount and date are required"} = result
    end

    test "creates single-currency transfer successfully", %{bank: bank, cash: cash} do
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: cash.id,
          amount: Money.new(100, :BRL),
          date: Date.utc_today()
        })

      result = CreateUnderlyingTransfer.create_transfer_for_transaction(changeset)

      assert {:ok, transfer, notifications} = result
      assert transfer.amount == Money.new(100, :BRL)
      assert is_list(notifications)
    end

    test "creates multi-currency transfer with exchange rate", %{bank: bank, usd_account: usd} do
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: usd.id,
          amount: Money.new(100, :USD),
          source_amount: Money.new(520, :BRL),
          date: Date.utc_today()
        })

      result = CreateUnderlyingTransfer.create_transfer_for_transaction(changeset)

      assert {:ok, %{source_transfer: source, target_transfer: target, exchange_rate: rate},
              notifications} = result

      assert source.amount == Money.new(520, :BRL)
      assert target.amount == Money.new(100, :USD)
      assert Decimal.eq?(rate, Decimal.new("5.2"))
      assert is_list(notifications)
    end

    test "handles zero source_amount in exchange rate calculation", %{
      bank: bank,
      usd_account: usd
    } do
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: usd.id,
          amount: Money.new(100, :USD),
          source_amount: Money.new(0, :BRL),
          date: Date.utc_today()
        })

      result = CreateUnderlyingTransfer.create_transfer_for_transaction(changeset)

      # Should handle gracefully - exchange rate will be 0
      assert {:ok, %{exchange_rate: rate}, _notifications} = result
      assert Decimal.eq?(rate, Decimal.new(0))
    end
  end
end

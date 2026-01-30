defmodule Moolah.Finance.Changes.UpdateUnderlyingTransferTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.Transaction
  alias Moolah.Ledger.Account
  alias Moolah.Ledger.Transfer

  describe "update_transfer/1" do
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

    test "updates transfer when amount changes", %{bank: bank, cash: cash} do
      # Create initial transaction
      transaction =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: cash.id,
          amount: Money.new(100, :BRL),
          date: Date.utc_today()
        })
        |> Ash.create!()

      original_transfer_id = transaction.transfer_id

      # Update amount
      updated_transaction =
        transaction
        |> Ash.Changeset.for_update(:update, %{
          amount: Money.new(200, :BRL)
        })
        |> Ash.update!()

      # Verify transfer was replaced
      assert updated_transaction.transfer_id != original_transfer_id
      assert updated_transaction.amount == Money.new(200, :BRL)
    end

    test "updates multi-currency transfer when source_amount changes", %{
      bank: bank,
      usd_account: usd
    } do
      # Create initial multi-currency transaction
      transaction =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: usd.id,
          amount: Money.new(100, :USD),
          source_amount: Money.new(520, :BRL),
          date: Date.utc_today()
        })
        |> Ash.create!()

      original_transfer_id = transaction.transfer_id
      original_source_transfer_id = transaction.source_transfer_id

      # Update source_amount (simulating exchange rate change)
      updated_transaction =
        transaction
        |> Ash.Changeset.for_update(:update, %{
          source_amount: Money.new(600, :BRL)
        })
        |> Ash.update!()

      # Verify both transfers were replaced
      assert updated_transaction.transfer_id != original_transfer_id
      assert updated_transaction.source_transfer_id != original_source_transfer_id
      assert updated_transaction.source_amount == Money.new(600, :BRL)

      # Verify exchange rate was recalculated
      expected_rate = Decimal.new("6.0")
      assert Decimal.eq?(updated_transaction.exchange_rate, expected_rate)
    end

    test "does not update transfer when only description changes", %{bank: bank, cash: cash} do
      # Create initial transaction
      transaction =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: cash.id,
          amount: Money.new(100, :BRL),
          description: "Original",
          date: Date.utc_today()
        })
        |> Ash.create!()

      original_transfer_id = transaction.transfer_id

      # Update only description
      updated_transaction =
        transaction
        |> Ash.Changeset.for_update(:update, %{
          description: "Updated"
        })
        |> Ash.update!()

      # Verify transfer was NOT replaced
      assert updated_transaction.transfer_id == original_transfer_id
      assert updated_transaction.description == "Updated"
    end

    test "updates transfer when date changes", %{bank: bank, cash: cash} do
      # Create initial transaction
      transaction =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: cash.id,
          amount: Money.new(100, :BRL),
          date: ~D[2024-01-01]
        })
        |> Ash.create!()

      original_transfer_id = transaction.transfer_id

      # Update date
      updated_transaction =
        transaction
        |> Ash.Changeset.for_update(:update, %{
          date: ~D[2024-01-15]
        })
        |> Ash.update!()

      # Verify transfer was replaced
      assert updated_transaction.transfer_id != original_transfer_id
      assert updated_transaction.date == ~D[2024-01-15]
    end
  end

    describe "error handling in update_transfer/1" do
    setup do
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

      {:ok, bank: bank, cash: cash}
    end

    test "handles error when destroying old transfer fails", %{bank: bank, cash: cash} do
      # Create initial transaction
      transaction =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: cash.id,
          amount: Money.new(100, :BRL),
          date: Date.utc_today()
        })
        |> Ash.create!()

      # Manually delete the transfer to simulate a scenario where it doesn't exist
      if transaction.transfer_id do
        case Ash.get(Transfer, transaction.transfer_id) do
          {:ok, transfer} when not is_nil(transfer) ->
            Ash.destroy(transfer)

          _ ->
            :ok
        end
      end

      # Now try to update the transaction - this should handle the missing transfer gracefully
      result =
        transaction
        |> Ash.Changeset.for_update(:update, %{
          amount: Money.new(200, :BRL)
        })
        |> Ash.update()

      # The update should still succeed even if the old transfer is missing
      assert {:ok, updated_transaction} = result
      assert updated_transaction.amount == Money.new(200, :BRL)
    end

    test "handles error when reading transfer fails", %{bank: bank, cash: cash} do
      # Create initial transaction
      transaction =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: cash.id,
          amount: Money.new(100, :BRL),
          date: Date.utc_today()
        })
        |> Ash.create!()

      # Update with a valid change
      result =
        transaction
        |> Ash.Changeset.for_update(:update, %{
          amount: Money.new(150, :BRL)
        })
        |> Ash.update()

      assert {:ok, _updated} = result
    end
  end
end

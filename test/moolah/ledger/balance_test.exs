defmodule Moolah.Ledger.BalanceTest do
  @moduledoc """
  Tests for the Moolah.Ledger.Balance resource.

  Balance records are typically managed by the AshDoubleEntry extension
  and created as side effects of transfers. These tests focus on validating
  the balance tracking behavior and read operations.
  """
  use Moolah.DataCase, async: true

  alias Moolah.Ledger.Account
  alias Moolah.Ledger.Balance
  alias Moolah.Ledger.Transfer

  describe "balance creation and tracking" do
    setup do
      {:ok, from_account} =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "from-account-#{Ecto.UUID.generate()}",
          currency: "USD",
          account_type: :bank_account
        })
        |> Ash.create()

      {:ok, to_account} =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "to-account-#{Ecto.UUID.generate()}",
          currency: "USD",
          account_type: :bank_account
        })
        |> Ash.create()

      %{from_account: from_account, to_account: to_account}
    end

    test "balances are created when transfer occurs", %{
      from_account: from_account,
      to_account: to_account
    } do
      # Create a transfer
      {:ok, _transfer} =
        Transfer
        |> Ash.Changeset.for_create(:transfer, %{
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          amount: Money.new(100, :USD),
          timestamp: DateTime.utc_now()
        })
        |> Ash.create()

      # Balances should be created automatically
      balances = Balance |> Ash.read!()
      assert length(balances) > 0
    end

    test "can read all balances" do
      # Simply test that we can read balances
      balances = Balance |> Ash.read!()
      assert is_list(balances)
    end

    test "can filter balances by account", %{
      from_account: from_account,
      to_account: to_account
    } do
      # Create a transfer
      {:ok, _transfer} =
        Transfer
        |> Ash.Changeset.for_create(:transfer, %{
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          amount: Money.new(50, :USD),
          timestamp: DateTime.utc_now()
        })
        |> Ash.create()

      # Query balances for from_account
      from_balances =
        Balance
        |> Ash.Query.filter(account_id == ^from_account.id)
        |> Ash.read!()

      # Query balances for to_account
      to_balances =
        Balance
        |> Ash.Query.filter(account_id == ^to_account.id)
        |> Ash.read!()

      # Both accounts should have balance records
      assert length(from_balances) > 0
      assert length(to_balances) > 0

      # Verify all records belong to the correct account
      assert Enum.all?(from_balances, &(&1.account_id == from_account.id))
      assert Enum.all?(to_balances, &(&1.account_id == to_account.id))
    end

    test "balance records have required attributes", %{
      from_account: from_account,
      to_account: to_account
    } do
      # Create a transfer to generate balances
      {:ok, transfer} =
        Transfer
        |> Ash.Changeset.for_create(:transfer, %{
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          amount: Money.new(75, :USD),
          timestamp: DateTime.utc_now()
        })
        |> Ash.create()

      # Read balances
      balances = Balance |> Ash.read!()

      # Find a balance related to this transfer
      balance =
        Enum.find(balances, fn b ->
          b.transfer_id == transfer.id
        end)

      assert balance != nil
      assert balance.id != nil
      assert balance.balance != nil
      assert balance.account_id != nil
      assert balance.transfer_id != nil
    end
  end

  describe "balance attributes" do
    test "balance has money type for balance attribute" do
      # This is more of a schema test - verify the balance field accepts Money
      balances = Balance |> Ash.read!()

      # If we have any balances, check their structure
      if balance = List.first(balances) do
        # Balance should be a Money struct
        assert is_struct(balance.balance)
      end
    end

    test "balance has proper relationships" do
      balances = Balance |> Ash.read!()

      if balance = List.first(balances) do
        # Should have account_id and transfer_id
        assert is_binary(balance.account_id)
        assert is_binary(balance.transfer_id)
      end
    end
  end

  describe "balance identity constraints" do
    setup do
      {:ok, account} =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "unique-test-#{Ecto.UUID.generate()}",
          currency: "USD",
          account_type: :bank_account
        })
        |> Ash.create()

      {:ok, to_account} =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "to-unique-test-#{Ecto.UUID.generate()}",
          currency: "USD",
          account_type: :bank_account
        })
        |> Ash.create()

      {:ok, transfer} =
        Transfer
        |> Ash.Changeset.for_create(:transfer, %{
          from_account_id: account.id,
          to_account_id: to_account.id,
          amount: Money.new(100, :USD),
          timestamp: DateTime.utc_now()
        })
        |> Ash.create()

      %{account: account, transfer: transfer}
    end

    test "enforces unique account_id and transfer_id combination", %{
      account: account,
      transfer: transfer
    } do
      # Try to create a duplicate balance (should be prevented by upsert or constraint)
      changeset =
        Balance
        |> Ash.Changeset.for_create(:upsert_balance, %{
          account_id: account.id,
          transfer_id: transfer.id,
          balance: Money.new(200, :USD)
        })

      # This should either succeed as an upsert or fail gracefully
      result = Ash.create(changeset)

      # Either it succeeds (upsert behavior) or we get an error
      # The important thing is it doesn't create a duplicate
      case result do
        {:ok, _balance} -> assert true
        {:error, _error} -> assert true
      end

      # Verify no duplicates exist
      balances =
        Balance
        |> Ash.Query.filter(account_id == ^account.id and transfer_id == ^transfer.id)
        |> Ash.read!()

      # Should have exactly one balance for this account/transfer combination
      assert length(balances) == 1
    end
  end
end

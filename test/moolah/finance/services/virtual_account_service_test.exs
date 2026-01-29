defmodule Moolah.Finance.Services.VirtualAccountServiceTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.Services.VirtualAccountService
  alias Moolah.Ledger.Account

  describe "get_or_create/3" do
    test "partitions virtual accounts by currency for the same category" do
      category_id = Ash.UUID.generate()

      # Create BRL account
      {:ok, brl_account} = VirtualAccountService.get_or_create(category_id, :expense, "BRL")
      assert brl_account.currency == "BRL"
      assert brl_account.identifier == "expense:BRL:#{category_id}"

      # Create USD account for the same category
      {:ok, usd_account} = VirtualAccountService.get_or_create(category_id, :expense, "USD")
      assert usd_account.currency == "USD"
      assert usd_account.identifier == "expense:USD:#{category_id}"

      # Verify they are different records
      assert brl_account.id != usd_account.id
    end

    test "handles race conditions gracefully via upserts" do
      category_id = Ash.UUID.generate()
      identifier = "expense:BRL:#{category_id}"

      # Manually create the account first (simulating a concurrent process winning)
      existing =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: identifier,
          currency: "BRL",
          account_type: :expense_category
        })
        |> Ash.create!()

      # Call service (simulating the second concurrent process)
      {:ok, account} = VirtualAccountService.get_or_create(category_id, :expense, "BRL")

      # Should return the existing one instead of crashing with a unique constraint error
      assert account.id == existing.id
    end
  end

  describe "get_or_create_trading_account!/1" do
    test "creates and retrieves trading accounts using upserts" do
      # First call creates
      account1 = VirtualAccountService.get_or_create_trading_account!("BRL")
      assert account1.account_type == :trading_account
      assert account1.identifier == "trading:BRL"

      # Second call retrieves existing
      account2 = VirtualAccountService.get_or_create_trading_account!("BRL")
      assert account1.id == account2.id
    end
  end
end

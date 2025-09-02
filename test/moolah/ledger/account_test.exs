defmodule Moolah.Ledger.AccountTest do
  @moduledoc """
  Tests for the Moolah.Ledger.Account resource.
  """
  use Moolah.DataCase, async: true

  alias Moolah.Ledger.Account

  describe "account creation" do
    test "successfully creates an account with all required fields" do
      assert {:ok, account} =
               Account
               |> Ash.Changeset.for_create(:open, %{
                 identifier: "test-bank-account",
                 currency: "USD",
                 account_type: :bank_account
               })
               |> Ash.create()

      assert account.identifier == "test-bank-account"
      assert account.currency == "USD"
      assert account.account_type == :bank_account
    end

    test "successfully creates accounts with different account types" do
      account_types = [:bank_account, :money_account, :investment_account]

      for account_type <- account_types do
        identifier = "test-#{account_type}"
        assert {:ok, account} =
                 Account
                 |> Ash.Changeset.for_create(:open, %{
                   identifier: identifier,
                   currency: "USD",
                   account_type: account_type
                 })
                 |> Ash.create()

        assert account.account_type == account_type
        assert account.identifier == identifier
      end
    end

    test "fails to create account without account_type" do
      assert {:error, error} =
               Account
               |> Ash.Changeset.for_create(:open, %{
                 identifier: "test-account-no-type",
                 currency: "USD"
               })
               |> Ash.create()

      # Check that account_type field is required
      assert %Ash.Error.Invalid{} = error
      assert Enum.any?(error.errors, fn
        %Ash.Error.Changes.Required{field: :account_type} -> true
        _ -> false
      end)
    end

    test "fails to create account with invalid account_type" do
      assert {:error, error} =
               Account
               |> Ash.Changeset.for_create(:open, %{
                 identifier: "test-invalid-type",
                 currency: "USD",
                 account_type: :invalid_type
               })
               |> Ash.create()

      # Check that constraint validation fails
      assert %Ash.Error.Invalid{} = error
      assert Enum.any?(error.errors, fn
        %Ash.Error.Changes.InvalidAttribute{field: :account_type} -> true
        _ -> false
      end)
    end

    test "fails to create account without identifier" do
      assert {:error, error} =
               Account
               |> Ash.Changeset.for_create(:open, %{
                 currency: "USD",
                 account_type: :bank_account
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error
      assert Enum.any?(error.errors, fn
        %Ash.Error.Changes.Required{field: :identifier} -> true
        _ -> false
      end)
    end

    test "fails to create account without currency" do
      assert {:error, error} =
               Account
               |> Ash.Changeset.for_create(:open, %{
                 identifier: "test-no-currency",
                 account_type: :bank_account
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error
      assert Enum.any?(error.errors, fn
        %Ash.Error.Changes.Required{field: :currency} -> true
        _ -> false
      end)
    end

    test "enforces unique identifier constraint" do
      # Create first account
      assert {:ok, _account} =
               Account
               |> Ash.Changeset.for_create(:open, %{
                 identifier: "duplicate-identifier",
                 currency: "USD",
                 account_type: :bank_account
               })
               |> Ash.create()

      # Attempt to create second account with same identifier
      assert {:error, error} =
               Account
               |> Ash.Changeset.for_create(:open, %{
                 identifier: "duplicate-identifier",
                 currency: "EUR",
                 account_type: :money_account
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error
      assert Enum.any?(error.errors, fn
        %Ash.Error.Changes.InvalidAttribute{field: :identifier} -> true
        _ -> false
      end)
    end
  end

  describe "account queries" do
    test "can read accounts by account_type" do
      # Create accounts of different types
      {:ok, bank_account} =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "bank-account-1",
          currency: "USD",
          account_type: :bank_account
        })
        |> Ash.create()

      {:ok, investment_account} =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "investment-account-1",
          currency: "USD",
          account_type: :investment_account
        })
        |> Ash.create()

      # Read all accounts and filter in Elixir for simplicity
      all_accounts = Account |> Ash.read!()
      bank_accounts = Enum.filter(all_accounts, &(&1.account_type == :bank_account))
      investment_accounts = Enum.filter(all_accounts, &(&1.account_type == :investment_account))

      assert length(bank_accounts) >= 1
      assert length(investment_accounts) >= 1
      assert bank_account.id in Enum.map(bank_accounts, & &1.id)
      assert investment_account.id in Enum.map(investment_accounts, & &1.id)
    end

    test "can read all accounts" do
      # Create a test account
      {:ok, account} =
        Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: "test-read-all",
          currency: "USD",
          account_type: :bank_account
        })
        |> Ash.create()

      # Read all accounts
      accounts = Account |> Ash.read!()

      assert is_list(accounts)
      assert account.id in Enum.map(accounts, & &1.id)
    end
  end

  describe "account validation rules" do
    test "validates account_type is one of allowed values" do
      allowed_types = [:bank_account, :money_account, :investment_account]
      for account_type <- allowed_types do
        assert {:ok, _account} =
                 Account
                 |> Ash.Changeset.for_create(:open, %{
                   identifier: "valid-type-#{account_type}",
                   currency: "USD",
                   account_type: account_type
                 })
                 |> Ash.create()
      end
    end

    test "validates all required fields are present" do
      required_params = %{
        identifier: "test-required",
        currency: "USD",
        account_type: :bank_account
      }

      # Test missing each required field
      for field <- [:identifier, :currency, :account_type] do
        params = Map.delete(required_params, field)
        assert {:error, error} =
                 Account
                 |> Ash.Changeset.for_create(:open, params)
                 |> Ash.create()

        assert %Ash.Error.Invalid{} = error
        assert Enum.any?(error.errors, fn
          %Ash.Error.Changes.Required{field: ^field} -> true
          _ -> false
        end)
      end
    end
  end
end
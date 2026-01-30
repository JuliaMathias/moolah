defmodule Moolah.Finance.Validations.CurrencyMatchTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.Transaction
  alias Moolah.Ledger.Account

  setup do
    bank =
      Account
      |> Ash.Changeset.for_create(:open, %{
        identifier: "checking:#{Ecto.UUID.generate()}",
        currency: "BRL",
        account_type: :bank_account
      })
      |> Ash.create!()

    dollar_account =
      Account
      |> Ash.Changeset.for_create(:open, %{
        identifier: "dollar:#{Ecto.UUID.generate()}",
        currency: "USD",
        account_type: :bank_account
      })
      |> Ash.create!()

    now = DateTime.utc_now()

    food =
      Moolah.Repo.insert!(%Moolah.Finance.LifeAreaCategory{
        id: Ash.UUID.generate(),
        name: "Food",
        icon: "pizza",
        color: "#F1C40F",
        transaction_type: :debit,
        depth: 0,
        inserted_at: now,
        updated_at: now
      })

    comfort =
      Moolah.Repo.insert!(%Moolah.Finance.BudgetCategory{
        id: Ash.UUID.generate(),
        name: "Comfort",
        color: "#FF5733",
        icon: "mask",
        inserted_at: now,
        updated_at: now
      })

    {:ok, bank: bank, dollar: dollar_account, food: food, comfort: comfort}
  end

  describe "CurrencyMatch Validation" do
    test "fails if debit currency does not match account currency", %{
      bank: bank,
      food: food,
      comfort: comfort
    } do
      # Bank is BRL, trying to spend USD
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :debit,
          account_id: bank.id,
          amount: Money.new("20.00", :USD),
          budget_category_id: comfort.id,
          life_area_category_id: food.id,
          date: Date.utc_today()
        })

      assert {:error, error} = Ash.create(changeset)
      assert %Ash.Error.Invalid{} = error

      assert Enum.any?(error.errors, fn e ->
               e.field == :account_id &&
                 to_string(e.message) =~ "currency USD does not match account currency BRL"
             end)
    end

    test "fails if simple transfer currency does not match source account", %{
      bank: bank
    } do
      # Simple transfer (no source_amount) BRL -> BRL (requested as USD)
      # Source account is BRL
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: bank.id,
          amount: Money.new("100.00", :USD)
        })

      assert {:error, error} = Ash.create(changeset)

      assert Enum.any?(error.errors, fn e ->
               e.field == :account_id &&
                 to_string(e.message) =~ "currency USD does not match account currency BRL"
             end)
    end

    test "fails if multi-currency transfer source currency does not match source account", %{
      bank: bank,
      dollar: dollar
    } do
      # Source (Bank) is BRL. We send source_amount as EUR (wrong) to target USD
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: dollar.id,
          amount: Money.new("100.00", :USD),
          source_amount: Money.new("110.00", :EUR)
        })

      assert {:error, error} = Ash.create(changeset)

      assert Enum.any?(error.errors, fn e ->
               e.field == :account_id &&
                 to_string(e.message) =~ "currency EUR does not match account currency BRL"
             end)
    end

    test "fails if multi-currency transfer target currency does not match target account", %{
      bank: bank,
      dollar: dollar
    } do
      # Source (Bank) is BRL. Target (Dollar) is USD. We send amount as EUR (wrong)
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: dollar.id,
          amount: Money.new("100.00", :EUR),
          source_amount: Money.new("530.00", :BRL)
        })

      assert {:error, error} = Ash.create(changeset)

      assert Enum.any?(error.errors, fn e ->
               e.field == :target_account_id &&
                 to_string(e.message) =~ "currency EUR does not match account currency USD"
             end)
    end

    test "succeeds when currencies match their respective accounts in multi-currency", %{
      bank: bank,
      dollar: dollar
    } do
      # Source (Bank) BRL matches source_amount BRL
      # Target (Dollar) USD matches amount USD
      changeset =
        Transaction
        |> Ash.Changeset.for_create(:create, %{
          transaction_type: :transfer,
          account_id: bank.id,
          target_account_id: dollar.id,
          amount: Money.new("100.00", :USD),
          source_amount: Money.new("530.00", :BRL)
        })

      assert {:ok, _transaction} = Ash.create(changeset)
    end
  end
end

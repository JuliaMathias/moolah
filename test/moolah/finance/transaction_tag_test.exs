defmodule Moolah.Finance.TransactionTagTest do
  @moduledoc """
  Tests for tagging transactions.
  """

  use Moolah.DataCase, async: false

  alias Moolah.Finance.BudgetCategory
  alias Moolah.Finance.LifeAreaCategory
  alias Moolah.Finance.Transaction
  alias Moolah.Ledger.Account

  setup do
    account =
      Account
      |> Ash.Changeset.for_create(:open, %{
        identifier: unique_id("bank_account"),
        currency: "BRL",
        account_type: :bank_account
      })
      |> Ash.create!()

    budget_category = create_budget_category("Food")

    life_area =
      LifeAreaCategory
      |> Ash.Changeset.for_create(:create, %{
        name: unique_id("Personal"),
        color: "#FFFFFF",
        icon: "person",
        transaction_type: :debit
      })
      |> Ash.create!()

    %{account: account, budget_category: budget_category, life_area: life_area}
  end

  test "creates tags on demand during transaction creation", %{
    account: account,
    budget_category: budget_category,
    life_area: life_area
  } do
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: account.id,
        budget_category_id: budget_category.id,
        life_area_category_id: life_area.id,
        amount: Money.new(25, :BRL),
        tags: [
          %{name: "Groceries", color: "#22C55E"},
          %{name: "Weekend", color: "#F59E0B"}
        ]
      })
      |> Ash.create!()

    transaction = Ash.load!(transaction, :tags)

    tag_names = MapSet.new(Enum.map(transaction.tags, &to_string(&1.name)))
    assert tag_names == MapSet.new(["Groceries", "Weekend"])
  end

  test "updates transaction tags by replacing the tag list", %{
    account: account,
    budget_category: budget_category,
    life_area: life_area
  } do
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: account.id,
        budget_category_id: budget_category.id,
        life_area_category_id: life_area.id,
        amount: Money.new(10, :BRL),
        tags: [
          %{name: "Groceries", color: "#22C55E"},
          %{name: "Weekend", color: "#F59E0B"}
        ]
      })
      |> Ash.create!()

    updated =
      transaction
      |> Ash.Changeset.for_update(:update, %{
        tags: [%{name: "Groceries"}]
      })
      |> Ash.update!()

    updated = Ash.load!(updated, :tags)
    assert MapSet.new(Enum.map(updated.tags, &to_string(&1.name))) == MapSet.new(["Groceries"])
  end

  test "clears tags when an empty list is provided", %{
    account: account,
    budget_category: budget_category,
    life_area: life_area
  } do
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: account.id,
        budget_category_id: budget_category.id,
        life_area_category_id: life_area.id,
        amount: Money.new(5, :BRL),
        tags: [
          %{name: "Groceries", color: "#22C55E"}
        ]
      })
      |> Ash.create!()

    cleared =
      transaction
      |> Ash.Changeset.for_update(:update, %{tags: []})
      |> Ash.update!()

    cleared = Ash.load!(cleared, :tags)
    assert cleared.tags == []
  end

  test "dedupes duplicate tag inputs by name", %{
    account: account,
    budget_category: budget_category,
    life_area: life_area
  } do
    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: account.id,
        budget_category_id: budget_category.id,
        life_area_category_id: life_area.id,
        amount: Money.new(15, :BRL),
        tags: [
          %{name: "Groceries", color: "#22C55E"},
          %{name: "groceries", color: "#22C55E"}
        ]
      })
      |> Ash.create!()

    transaction = Ash.load!(transaction, :tags)

    assert Enum.map(transaction.tags, &to_string(&1.name)) == ["Groceries"]
  end

  test "relates to existing tags case-insensitively", %{
    account: account,
    budget_category: budget_category,
    life_area: life_area
  } do
    {:ok, tag} =
      Moolah.Finance.Tag
      |> Ash.Changeset.for_create(:create, %{
        name: "Groceries",
        color: "#22C55E"
      })
      |> Ash.create()

    transaction =
      Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: account.id,
        budget_category_id: budget_category.id,
        life_area_category_id: life_area.id,
        amount: Money.new(12, :BRL),
        tags: [%{name: "groceries"}]
      })
      |> Ash.create!()

    transaction = Ash.load!(transaction, :tags)

    assert Enum.map(transaction.tags, & &1.id) == [tag.id]
  end

  test "fails when trying to reuse an archived tag name", %{
    account: account,
    budget_category: budget_category,
    life_area: life_area
  } do
    {:ok, tag} =
      Moolah.Finance.Tag
      |> Ash.Changeset.for_create(:create, %{
        name: "Archived",
        color: "#F59E0B"
      })
      |> Ash.create()

    assert :ok = Ash.destroy(tag)

    assert {:error, %Ash.Error.Invalid{}} =
             Transaction
             |> Ash.Changeset.for_create(:create, %{
               transaction_type: :debit,
               account_id: account.id,
               budget_category_id: budget_category.id,
               life_area_category_id: life_area.id,
               amount: Money.new(9, :BRL),
               tags: [%{name: "Archived", color: "#F59E0B"}]
             })
             |> Ash.create()
  end

  test "requires color when creating a brand new tag via transaction input", %{
    account: account,
    budget_category: budget_category,
    life_area: life_area
  } do
    assert {:error, %Ash.Error.Invalid{}} =
             Transaction
             |> Ash.Changeset.for_create(:create, %{
               transaction_type: :debit,
               account_id: account.id,
               budget_category_id: budget_category.id,
               life_area_category_id: life_area.id,
               amount: Money.new(8, :BRL),
               tags: [%{name: "Needs Color"}]
             })
             |> Ash.create()
  end

  @spec create_budget_category(String.t()) :: BudgetCategory.t()
  defp create_budget_category(name) do
    now = DateTime.utc_now()

    Moolah.Repo.insert!(%BudgetCategory{
      id: Ash.UUID.generate(),
      name: unique_id(name),
      color: "#FF5733",
      icon: "masks",
      inserted_at: now,
      updated_at: now
    })
  end

  @spec unique_id(String.t()) :: String.t()
  defp unique_id(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end
end

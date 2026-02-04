defmodule Moolah.Finance.Validations.NoCycleReferenceTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.LifeAreaCategory

  describe "no_cycle_reference validation" do
    test "allows creating a root category with no parent" do
      changeset =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Root",
          icon: "home",
          color: "#3B82F6",
          transaction_type: :debit
        })

      assert {:ok, _category} = Ash.create(changeset)
    end

    test "allows creating a valid parent-child relationship" do
      {:ok, parent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      changeset =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child",
          icon: "file",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: parent.id
        })

      assert {:ok, child} = Ash.create(changeset)
      assert child.parent_id == parent.id
    end

    test "prevents self-reference (category as its own parent)" do
      # First create a category
      {:ok, category} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Self Ref Test",
          icon: "warning",
          color: "#EF4444",
          transaction_type: :debit
        })
        |> Ash.create()

      # Try to update it to reference itself
      changeset =
        category
        |> Ash.Changeset.for_update(:update, %{
          parent_id: category.id
        })

      assert {:error, error} = Ash.update(changeset)
      assert %Ash.Error.Invalid{} = error

      assert Enum.any?(error.errors, fn e ->
               e.field == :parent_id &&
                 to_string(e.message) =~ "cannot be the same as the category itself"
             end)
    end

    test "prevents direct circular reference (A -> B -> A)" do
      # Create category A
      {:ok, category_a} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Category A",
          icon: "a",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      # Create category B with A as parent
      {:ok, category_b} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Category B",
          icon: "b",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: category_a.id
        })
        |> Ash.create()

      # Try to update A to have B as parent (creates cycle)
      changeset =
        category_a
        |> Ash.Changeset.for_update(:update, %{
          parent_id: category_b.id
        })

      assert {:error, error} = Ash.update(changeset)

      assert Enum.any?(error.errors, fn e ->
               e.field == :parent_id &&
                 to_string(e.message) =~ "creates a circular reference"
             end)
    end

    test "prevents deeper circular reference (A -> B -> C -> A)" do
      # Create a chain: A (root)
      {:ok, category_a} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Category A",
          icon: "a",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      # B -> A (but will hit max depth, so we can't test 3-level cycle with current constraints)
      # However, we can test the logic by attempting to create the cycle at the 2-level limit

      {:ok, category_b} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Category B",
          icon: "b",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: category_a.id
        })
        |> Ash.create()

      # Try to make A point to B, creating A -> B -> A
      changeset =
        category_a
        |> Ash.Changeset.for_update(:update, %{
          parent_id: category_b.id
        })

      assert {:error, error} = Ash.update(changeset)

      # Should catch the circular reference
      assert Enum.any?(error.errors, fn e ->
               e.field == :parent_id &&
                 to_string(e.message) =~ "creates a circular reference"
             end)
    end

    test "handles non-existent parent by returning error" do
      fake_uuid = Ash.UUID.generate()

      changeset =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Orphan",
          icon: "question",
          color: "#6B7280",
          transaction_type: :debit,
          parent_id: fake_uuid
        })

      # The validation checks if parent exists
      assert {:error, error} = Ash.create(changeset)

      # Could fail either from validation or from foreign key constraint
      assert error != nil
    end

    test "allows moving category to a different valid parent" do
      # Create two root categories
      {:ok, parent1} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent 1",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      {:ok, parent2} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent 2",
          icon: "folder-open",
          color: "#10B981",
          transaction_type: :debit
        })
        |> Ash.create()

      # Create child under parent1
      {:ok, child} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child",
          icon: "file",
          color: "#F59E0B",
          transaction_type: :debit,
          parent_id: parent1.id
        })
        |> Ash.create()

      # Move child to parent2 - should succeed
      changeset =
        child
        |> Ash.Changeset.for_update(:update, %{
          parent_id: parent2.id
        })

      assert {:ok, updated_child} = Ash.update(changeset)
      assert updated_child.parent_id == parent2.id
    end
  end
end

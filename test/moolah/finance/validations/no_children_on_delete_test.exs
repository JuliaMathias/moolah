defmodule Moolah.Finance.Validations.NoChildrenOnDeleteTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.LifeAreaCategory

  describe "no_children_on_delete validation" do
    test "allows deleting a category with no children" do
      {:ok, category} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Childless Category",
          icon: "single",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      # Should succeed since it has no children
      assert :ok = Ash.destroy!(category, action: :destroy)
    end

    test "prevents deleting a category with one child" do
      # Create parent
      {:ok, parent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      # Create child
      {:ok, _child} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child",
          icon: "file",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: parent.id
        })
        |> Ash.create()

      # Try to delete parent - should fail
      assert {:error, error} =
               Ash.Changeset.for_destroy(parent, :destroy)
               |> Ash.destroy()

      assert %Ash.Error.Invalid{} = error

      assert Enum.any?(error.errors, fn e ->
               e.field == :id &&
                 to_string(e.message) =~ "cannot delete category that has 1 child category"
             end)
    end

    test "prevents deleting a category with multiple children" do
      # Create parent
      {:ok, parent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      # Create multiple children
      {:ok, _child1} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child 1",
          icon: "file",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: parent.id
        })
        |> Ash.create()

      {:ok, _child2} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child 2",
          icon: "document",
          color: "#F59E0B",
          transaction_type: :debit,
          parent_id: parent.id
        })
        |> Ash.create()

      {:ok, _child3} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child 3",
          icon: "page",
          color: "#EF4444",
          transaction_type: :debit,
          parent_id: parent.id
        })
        |> Ash.create()

      # Try to delete parent - should fail with count
      assert {:error, error} =
               Ash.Changeset.for_destroy(parent, :destroy)
               |> Ash.destroy()

      assert Enum.any?(error.errors, fn e ->
               e.field == :id &&
                 to_string(e.message) =~ "cannot delete category that has 3 child categories"
             end)
    end

    test "allows deleting child categories first, then parent" do
      # Create parent
      {:ok, parent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      # Create child
      {:ok, child} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child",
          icon: "file",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: parent.id
        })
        |> Ash.create()

      # Delete child first - should succeed
      assert :ok = Ash.destroy!(child, action: :destroy)

      # Now delete parent - should succeed since it has no children
      assert :ok = Ash.destroy!(parent, action: :destroy)
    end

    test "allows deleting a child that has no children of its own" do
      # Create grandparent -> parent -> child hierarchy
      {:ok, grandparent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Grandparent",
          icon: "home",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      {:ok, parent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent",
          icon: "folder",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: grandparent.id
        })
        |> Ash.create()

      # Parent has no children, so it can be deleted even though grandparent has children
      assert :ok = Ash.destroy!(parent, action: :destroy)
    end

    test "proper pluralization in error messages" do
      # Create parent with 1 child
      {:ok, parent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      {:ok, _child} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child",
          icon: "file",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: parent.id
        })
        |> Ash.create()

      # Error message should use singular "category"
      assert {:error, error} =
               Ash.Changeset.for_destroy(parent, :destroy)
               |> Ash.destroy()

      assert Enum.any?(error.errors, fn e ->
               to_string(e.message) =~ "1 child category"
             end)

      # Create parent with 2 children for plural test
      {:ok, parent2} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent 2",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      {:ok, _child1} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child 1",
          icon: "file",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: parent2.id
        })
        |> Ash.create()

      {:ok, _child2} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child 2",
          icon: "document",
          color: "#F59E0B",
          transaction_type: :debit,
          parent_id: parent2.id
        })
        |> Ash.create()

      # Error message should use plural "categories"
      assert {:error, error2} =
               Ash.Changeset.for_destroy(parent2, :destroy)
               |> Ash.destroy()

      assert Enum.any?(error2.errors, fn e ->
               to_string(e.message) =~ "2 child categories"
             end)
    end
  end
end

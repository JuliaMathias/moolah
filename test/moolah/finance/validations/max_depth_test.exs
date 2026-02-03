defmodule Moolah.Finance.Validations.MaxDepthTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.LifeAreaCategory

  describe "MaxDepth validation" do
    test "allows creating a root category (depth 0)" do
      # Root category with no parent should succeed
      changeset =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Root Category",
          icon: "home",
          color: "#3B82F6",
          transaction_type: :debit
        })

      assert {:ok, _category} = Ash.create(changeset)
    end

    test "allows creating a child category (depth 1)" do
      # First create a root category
      {:ok, parent} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Parent Category",
          icon: "folder",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      # Child category should succeed
      changeset =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child Category",
          icon: "file",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: parent.id
        })

      assert {:ok, _category} = Ash.create(changeset)
    end

    test "prevents creating a grandchild category (depth 2)" do
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

      # Attempting to create grandchild should fail
      changeset =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Grandchild",
          icon: "document",
          color: "#EF4444",
          transaction_type: :debit,
          parent_id: child.id
        })

      assert {:error, error} = Ash.create(changeset)
      assert %Ash.Error.Invalid{} = error

      assert Enum.any?(error.errors, fn e ->
               e.field == :parent_id &&
                 to_string(e.message) =~ "would create depth 2, but maximum allowed is 1"
             end)
    end

    test "correctly calculates depth for existing hierarchy" do
      # Create a 2-level hierarchy
      {:ok, root} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Root",
          icon: "home",
          color: "#3B82F6",
          transaction_type: :debit
        })
        |> Ash.create()

      {:ok, child} =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Child",
          icon: "folder",
          color: "#10B981",
          transaction_type: :debit,
          parent_id: root.id
        })
        |> Ash.create()

      # Verify the child exists and has correct parent
      assert child.parent_id == root.id

      # Attempting to add a grandchild should fail with appropriate message
      changeset =
        LifeAreaCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Grandchild",
          icon: "file",
          color: "#F59E0B",
          transaction_type: :debit,
          parent_id: child.id
        })

      assert {:error, error} = Ash.create(changeset)

      assert Enum.any?(error.errors, fn e ->
               e.field == :parent_id && to_string(e.message) =~ "maximum allowed is 1"
             end)
    end

    test "handles non-existent parent gracefully" do
      # This tests the edge case where parent_id is set but parent doesn't exist
      # The validation should handle the error case
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

      # This will fail, but not necessarily due to max_depth validation
      # It might fail due to foreign key constraint instead
      assert {:error, _error} = Ash.create(changeset)
    end
  end
end

defmodule Moolah.Finance.LifeAreaCategoryTest do
  @moduledoc """
  Tests for the LifeAreaCategory resource with hierarchical structure.

  Tests cover:
  - Reading categories (all, roots, with children)
  - Creating categories (root and child)
  - Hierarchy validations (circular references, max depth)
  - Unique name constraints (scoped to parent)
  - Update functionality
  - Delete operations (prevention with children)
  - Seeded data verification
  - Relationship queries
  """

  use Moolah.DataCase, async: true

  alias Moolah.Finance.LifeAreaCategory

  describe "reading categories" do
    test "reads all categories" do
      # Create some test categories
      root = create_category(%{name: "Test Root", transaction_type: :debit})

      create_category(%{
          name: "Test Child",
          parent_id: root.id,
          transaction_type: :debit,
          depth: 1
        })

      assert {:ok, categories} = Ash.read(LifeAreaCategory)
      assert length(categories) >= 2
    end

    test "reads only root categories using :roots action" do
      # Create mix of root and child categories
      root1 = create_category(%{name: "Root 1", transaction_type: :debit})
      create_category(%{name: "Root 2", transaction_type: :credit})

      create_category(%{name: "Child", parent_id: root1.id, transaction_type: :debit, depth: 1})

      assert {:ok, roots} = Ash.read(LifeAreaCategory, action: :roots)

      root_names = Enum.map(roots, & &1.name)
      assert "Root 1" in root_names
      assert "Root 2" in root_names
      assert "Child" not in root_names
    end

    test "reads categories with children preloaded using :with_children action" do
      root = create_category(%{name: "Parent", transaction_type: :debit})

      create_category(%{name: "Child", parent_id: root.id, transaction_type: :debit, depth: 1})

      assert {:ok, categories} = Ash.read(LifeAreaCategory, action: :with_children)

      parent = Enum.find(categories, &(&1.name == "Parent"))
      assert parent != nil
      assert Ash.Resource.loaded?(parent, :children)
      assert length(parent.children) > 0
    end

    test "verifies all attributes present on read" do
      create_category(%{
          name: "Complete Category",
          description: "Test description",
          icon: "hero-star-solid",
          color: "#FF0000",
          transaction_type: :both,
          depth: 0
        })

      assert {:ok, categories} = Ash.read(LifeAreaCategory)
      read_category = Enum.find(categories, &(&1.name == "Complete Category"))
      assert read_category != nil

      assert read_category.name == "Complete Category"
      assert read_category.description == "Test description"
      assert read_category.icon == "hero-star-solid"
      assert read_category.color == "#FF0000"
      assert read_category.transaction_type == :both
      assert read_category.depth == 0
      assert read_category.parent_id == nil
      assert read_category.id != nil
      assert read_category.inserted_at != nil
      assert read_category.updated_at != nil
    end

    test "filters by transaction_type" do
      create_category(%{name: "Debit Cat", transaction_type: :debit})
      create_category(%{name: "Credit Cat", transaction_type: :credit})

      assert {:ok, all_cats} = Ash.read(LifeAreaCategory)
      debit_cats = Enum.filter(all_cats, &(&1.transaction_type == :debit))

      assert Enum.any?(debit_cats, &(&1.name == "Debit Cat"))
      assert not Enum.any?(debit_cats, &(&1.name == "Credit Cat"))
    end
  end

  describe "creating categories" do
    test "creates root category successfully" do
      assert {:ok, category} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "New Root",
                 icon: "hero-star-solid",
                 color: "#00FF00",
                 transaction_type: :debit,
                 depth: 0
               })
               |> Ash.create()

      assert category.name == "New Root"
      assert category.parent_id == nil
      assert category.depth == 0
      assert category.transaction_type == :debit
    end

    test "creates child category successfully" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      assert {:ok, child} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Child",
                 parent_id: parent.id,
                 icon: "hero-flag-solid",
                 color: "#0000FF",
                 transaction_type: :debit,
                 depth: 1
               })
               |> Ash.create()

      assert child.name == "Child"
      assert child.parent_id == parent.id
      assert child.depth == 1
    end

    test "validates transaction_type enum - valid values" do
      for type <- [:debit, :credit, :both] do
        assert {:ok, _category} =
                 LifeAreaCategory
                 |> Ash.Changeset.for_create(:create, %{
                   name: "Type #{type}",
                   icon: "hero-star-solid",
                   color: "#FF0000",
                   transaction_type: type
                 })
                 |> Ash.create()
      end
    end

    test "validates transaction_type enum - invalid value fails" do
      assert {:error, error} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Invalid Type",
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :invalid
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error
    end

    test "requires name, icon, color, and transaction_type" do
      # Missing name
      assert {:error, _} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :debit
               })
               |> Ash.create()

      # Missing icon
      assert {:error, _} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Missing Icon",
                 color: "#FF0000",
                 transaction_type: :debit
               })
               |> Ash.create()

      # Missing color
      assert {:error, _} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Missing Color",
                 icon: "hero-star-solid",
                 transaction_type: :debit
               })
               |> Ash.create()

      # Missing transaction_type
      assert {:error, _} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Missing Type",
                 icon: "hero-star-solid",
                 color: "#FF0000"
               })
               |> Ash.create()
    end

    test "description is optional" do
      assert {:ok, category} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "No Description",
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :debit
               })
               |> Ash.create()

      assert category.description == nil
    end
  end

  describe "hierarchy validations - circular references" do
    test "prevents self-reference" do
      category = create_category(%{name: "Self Ref", transaction_type: :debit})

      # Try to set parent to itself
      assert {:error, error} =
               category
               |> Ash.Changeset.for_update(:update, %{parent_id: category.id})
               |> Ash.update()

      assert %Ash.Error.Invalid{} = error
      assert error_message_contains?(error, "cannot be the same as the category itself")
    end

    test "prevents circular reference A -> B -> A" do
      cat_a = create_category(%{name: "Category A", transaction_type: :debit})

      cat_b =
        create_category(%{
          name: "Category B",
          parent_id: cat_a.id,
          transaction_type: :debit,
          depth: 1
        })

      # Try to make A a child of B (creates cycle)
      assert {:error, error} =
               cat_a
               |> Ash.Changeset.for_update(:update, %{parent_id: cat_b.id})
               |> Ash.update()

      assert %Ash.Error.Invalid{} = error
      assert error_message_contains?(error, "circular reference")
    end

    test "prevents deeper circular reference A -> B -> C -> A" do
      cat_a = create_category(%{name: "Category A", transaction_type: :debit})

      cat_b =
        create_category(%{
          name: "Category B",
          parent_id: cat_a.id,
          transaction_type: :debit,
          depth: 1
        })

      cat_c =
        create_category(%{
          name: "Category C",
          parent_id: cat_b.id,
          transaction_type: :debit,
          depth: 2
        })

      # This should fail because C can't have children (depth limit)
      # But if it could, trying to make A a child of C would create cycle
      assert {:error, error} =
               cat_a
               |> Ash.Changeset.for_update(:update, %{parent_id: cat_c.id})
               |> Ash.update()

      assert %Ash.Error.Invalid{} = error
    end
  end

  describe "hierarchy validations - max depth" do
    test "allows creating child category (depth 1)" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      assert {:ok, child} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Child",
                 parent_id: parent.id,
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :debit,
                 depth: 1
               })
               |> Ash.create()

      assert child.depth == 1
    end

    test "prevents creating grandchild (depth 2)" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      child =
        create_category(%{
          name: "Child",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      # Try to create grandchild
      assert {:error, error} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Grandchild",
                 parent_id: child.id,
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :debit,
                 depth: 2
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error

      assert error_message_contains?(error, "maximum allowed is 2") or
               error_message_contains?(error, "would create depth")
    end

    test "prevents moving category to exceed depth" do
      root1 = create_category(%{name: "Root 1", transaction_type: :debit})
      root2 = create_category(%{name: "Root 2", transaction_type: :debit})

      child =
        create_category(%{name: "Child", parent_id: root1.id, transaction_type: :debit, depth: 1})

      # Try to move child under another child (would create depth 2)
      another_child =
        create_category(%{
          name: "Another Child",
          parent_id: root2.id,
          transaction_type: :debit,
          depth: 1
        })

      assert {:error, error} =
               child
               |> Ash.Changeset.for_update(:update, %{parent_id: another_child.id})
               |> Ash.update()

      assert %Ash.Error.Invalid{} = error
    end
  end

  describe "hierarchy validations - unique name constraint" do
    test "allows same name under different parents" do
      parent1 = create_category(%{name: "Parent 1", transaction_type: :debit})
      parent2 = create_category(%{name: "Parent 2", transaction_type: :debit})

      # Create child with same name under different parents
      assert {:ok, child1} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Same Name",
                 parent_id: parent1.id,
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :debit,
                 depth: 1
               })
               |> Ash.create()

      assert {:ok, child2} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Same Name",
                 parent_id: parent2.id,
                 icon: "hero-flag-solid",
                 color: "#00FF00",
                 transaction_type: :debit,
                 depth: 1
               })
               |> Ash.create()

      assert child1.name == child2.name
      assert child1.parent_id != child2.parent_id
    end

    test "prevents same name under same parent" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      # Create first child
      create_category(%{
        name: "Duplicate",
        parent_id: parent.id,
        transaction_type: :debit,
        depth: 1
      })

      # Try to create another child with same name under same parent
      assert {:error, error} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Duplicate",
                 parent_id: parent.id,
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :debit,
                 depth: 1
               })
               |> Ash.create()

      assert %Ash.Error.Invalid{} = error
    end

    test "allows multiple root categories with same name (NULL parent_id handling)" do
      # PostgreSQL treats NULL as distinct in unique constraints
      assert {:ok, root1} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Same Root Name",
                 icon: "hero-star-solid",
                 color: "#FF0000",
                 transaction_type: :debit
               })
               |> Ash.create()

      assert {:ok, root2} =
               LifeAreaCategory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Same Root Name",
                 icon: "hero-flag-solid",
                 color: "#00FF00",
                 transaction_type: :credit
               })
               |> Ash.create()

      assert root1.name == root2.name
      assert root1.parent_id == nil
      assert root2.parent_id == nil
      assert root1.id != root2.id
    end
  end

  describe "update functionality" do
    test "updates category attributes" do
      category =
        create_category(%{
          name: "Original",
          description: "Old description",
          icon: "hero-star-solid",
          color: "#FF0000",
          transaction_type: :debit
        })

      assert {:ok, updated} =
               category
               |> Ash.Changeset.for_update(:update, %{
                 name: "Updated",
                 description: "New description",
                 icon: "hero-flag-solid",
                 color: "#00FF00",
                 transaction_type: :credit
               })
               |> Ash.update()

      assert updated.name == "Updated"
      assert updated.description == "New description"
      assert updated.icon == "hero-flag-solid"
      assert updated.color == "#00FF00"
      assert updated.transaction_type == :credit
    end

    test "moves category to different parent" do
      parent1 = create_category(%{name: "Parent 1", transaction_type: :debit})
      parent2 = create_category(%{name: "Parent 2", transaction_type: :debit})

      child =
        create_category(%{
          name: "Child",
          parent_id: parent1.id,
          transaction_type: :debit,
          depth: 1
        })

      assert {:ok, moved} =
               child
               |> Ash.Changeset.for_update(:update, %{parent_id: parent2.id})
               |> Ash.update()

      assert moved.parent_id == parent2.id
    end

    test "cannot update to create cycle" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      child =
        create_category(%{
          name: "Child",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      # Try to make parent a child of child
      assert {:error, error} =
               parent
               |> Ash.Changeset.for_update(:update, %{parent_id: child.id})
               |> Ash.update()

      assert %Ash.Error.Invalid{} = error
      assert error_message_contains?(error, "circular reference")
    end

    test "allows partial updates" do
      category =
        create_category(%{
          name: "Original",
          description: "Description",
          transaction_type: :debit
        })

      # Update only description
      assert {:ok, updated} =
               category
               |> Ash.Changeset.for_update(:update, %{description: "New description"})
               |> Ash.update()

      assert updated.name == "Original"
      assert updated.description == "New description"
      assert updated.transaction_type == :debit
    end
  end

  describe "delete operations" do
    test "allows deleting leaf category (no children)" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      child =
        create_category(%{name: "Leaf", parent_id: parent.id, transaction_type: :debit, depth: 1})

      result =
        child
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy()

      # Ash.destroy can return either {:ok, record} or :ok
      assert result == :ok or match?({:ok, _}, result)

      # Verify it's deleted
      assert {:error, _} = Ash.get(LifeAreaCategory, child.id)
    end

    test "prevents deleting parent with children" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      create_category(%{
          name: "Child",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      assert {:error, error} =
               parent
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy()

      assert %Ash.Error.Invalid{} = error
      assert error_message_contains?(error, "child")
    end

    test "provides helpful error message on delete with children" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      create_category(%{
          name: "Child 1",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      create_category(%{
          name: "Child 2",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      assert {:error, error} =
               parent
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy()

      assert error_message_contains?(error, "2")
      assert error_message_contains?(error, "categories")
    end
  end



  describe "relationship queries" do
    test "loads parent from child" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      child =
        create_category(%{
          name: "Child",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      assert {:ok, child_with_parent} = Ash.load(child, :parent)
      assert child_with_parent.parent.name == "Parent"
    end

    test "loads children from parent" do
      parent = create_category(%{name: "Parent", transaction_type: :debit})

      create_category(%{
          name: "Child 1",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      create_category(%{
          name: "Child 2",
          parent_id: parent.id,
          transaction_type: :debit,
          depth: 1
        })

      assert {:ok, parent_with_children} = Ash.load(parent, :children)
      assert length(parent_with_children.children) == 2

      child_names = Enum.map(parent_with_children.children, & &1.name)
      assert "Child 1" in child_names
      assert "Child 2" in child_names
    end

    test "navigates full hierarchy" do
      root = create_category(%{name: "Root", transaction_type: :debit})

      child =
        create_category(%{name: "Child", parent_id: root.id, transaction_type: :debit, depth: 1})

      # Load child with parent
      assert {:ok, child_with_parent} = Ash.load(child, :parent)
      assert child_with_parent.parent.name == "Root"
      assert child_with_parent.parent.parent_id == nil

      # Load root with children
      assert {:ok, root_with_children} = Ash.load(root, :children)
      assert length(root_with_children.children) > 0
      assert Enum.any?(root_with_children.children, &(&1.name == "Child"))
    end
  end

  # Helper functions

  @spec create_category(map()) :: LifeAreaCategory.t()
  defp create_category(attrs) do
    defaults = %{
      icon: "hero-star-solid",
      color: "#FF0000",
      depth: 0
    }

    attrs = Map.merge(defaults, attrs)

    Ash.Seed.seed!(LifeAreaCategory, attrs)
  end

  @spec error_message_contains?(Ash.Error.Invalid.t(), String.t()) :: boolean()
  defp error_message_contains?(error, text) do
    error.errors
    |> Enum.any?(fn e ->
      message = Map.get(e, :message, "")
      String.contains?(to_string(message), text)
    end)
  end
end

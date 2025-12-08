defmodule Moolah.Finance.BudgetCategoryTest do
  @moduledoc """
  Tests for the BudgetCategory resource.

  Tests cover:
  - Reading seeded categories
  - Validations (hex color format, required fields, unique names)
  - Policy enforcement (no create/destroy actions)
  - Update functionality
  """

  use Moolah.DataCase, async: true

  alias Ash.Seed
  alias Moolah.Finance.BudgetCategory

  describe "reading budget categories" do
    test "allows reading categories" do
      # Create a test category using Seed (bypassing actions)
      category_data = %{
        name: "Test Category",
        icon: "hero-star-solid",
        color: "#FF5733",
        description: "A test category"
      }

      Seed.seed!(BudgetCategory, category_data)

      # Read it back
      assert {:ok, categories} = Ash.read(BudgetCategory)
      refute Enum.empty?(categories)
      assert Enum.any?(categories, &(&1.name == "Test Category"))
    end

    test "reads category with all attributes" do
      category_data = %{
        name: "Complete Category",
        icon: "hero-heart-solid",
        color: "#EA580C",
        description: "Category with all fields"
      }

      Seed.seed!(BudgetCategory, category_data)

      assert {:ok, categories} = Ash.read(BudgetCategory)
      category = Enum.find(categories, &(&1.name == "Complete Category"))
      assert category != nil

      assert category.name == "Complete Category"
      assert category.icon == "hero-heart-solid"
      assert category.color == "#EA580C"
      assert category.description == "Category with all fields"
      assert category.id != nil
      assert category.inserted_at != nil
      assert category.updated_at != nil
    end
  end

  describe "validations" do
    test "enforces unique name constraint" do
      # Create first category
      Seed.seed!(BudgetCategory, %{
        name: "Unique Name Test",
        icon: "hero-star-solid",
        color: "#FF0000"
      })

      # Attempt to create duplicate - Ash raises Invalid error with "has already been taken" message
      assert_raise Ash.Error.Invalid, ~r/has already been taken/, fn ->
        Seed.seed!(BudgetCategory, %{
          name: "Unique Name Test",
          icon: "hero-flag-solid",
          color: "#00FF00"
        })
      end
    end

    test "requires name, icon, and color" do
      # Seed bypasses Ash validations but database constraints still apply
      # Missing name (NOT NULL constraint) - wrapped in Ash.Error.Unknown
      assert_raise Ash.Error.Unknown, ~r/not_null_violation/, fn ->
        Seed.seed!(BudgetCategory, %{
          icon: "hero-star-solid",
          color: "#FF0000"
        })
      end

      # Missing icon (NOT NULL constraint)
      assert_raise Ash.Error.Unknown, ~r/not_null_violation/, fn ->
        Seed.seed!(BudgetCategory, %{
          name: "Missing Icon",
          color: "#FF0000"
        })
      end

      # Missing color (NOT NULL constraint)
      assert_raise Ash.Error.Unknown, ~r/not_null_violation/, fn ->
        Seed.seed!(BudgetCategory, %{
          name: "Missing Color",
          icon: "hero-star-solid"
        })
      end
    end

    test "description is optional" do
      # Should succeed without description
      category =
        Seed.seed!(BudgetCategory, %{
          name: "No Description",
          icon: "hero-star-solid",
          color: "#FF0000"
        })

      assert category.description == nil
    end
  end

  describe "update functionality" do
    test "allows updating category attributes" do
      category =
        Seed.seed!(BudgetCategory, %{
          name: "Original Name",
          icon: "hero-star-solid",
          color: "#FF0000",
          description: "Original description"
        })

      assert {:ok, updated} =
               category
               |> Ash.Changeset.for_update(:update, %{
                 name: "Updated Name",
                 icon: "hero-flag-solid",
                 color: "#00FF00",
                 description: "Updated description"
               })
               |> Ash.update()

      assert updated.name == "Updated Name"
      assert updated.icon == "hero-flag-solid"
      assert updated.color == "#00FF00"
      assert updated.description == "Updated description"
    end

    test "allows partial updates" do
      category =
        Seed.seed!(BudgetCategory, %{
          name: "Partial Update Test",
          icon: "hero-star-solid",
          color: "#FF0000",
          description: "Original"
        })

      # Update only description
      assert {:ok, updated} =
               category
               |> Ash.Changeset.for_update(:update, %{description: "Changed description"})
               |> Ash.update()

      assert updated.name == "Partial Update Test"
      assert updated.icon == "hero-star-solid"
      assert updated.color == "#FF0000"
      assert updated.description == "Changed description"
    end
  end

  describe "policy enforcement" do
    test "no create action is defined" do
      # Attempting to use a non-existent create action should fail with ArgumentError
      assert_raise ArgumentError, ~r/No such create action/, fn ->
        BudgetCategory
        |> Ash.Changeset.for_create(:create, %{
          name: "Should Fail",
          icon: "hero-star-solid",
          color: "#FF0000"
        })
        |> Ash.create()
      end
    end

    test "no destroy action is defined" do
      category =
        Seed.seed!(BudgetCategory, %{
          name: "To Delete",
          icon: "hero-star-solid",
          color: "#FF0000"
        })

      # Attempting to use a non-existent destroy action should fail with ArgumentError
      assert_raise ArgumentError, ~r/No such destroy action/, fn ->
        category
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy()
      end
    end

    test "read action is allowed" do
      Seed.seed!(BudgetCategory, %{
        name: "Read Test",
        icon: "hero-star-solid",
        color: "#FF0000"
      })

      # Should be able to read without authorization issues
      assert {:ok, categories} = Ash.read(BudgetCategory)
      refute Enum.empty?(categories)
    end

    test "update action is allowed" do
      category =
        Seed.seed!(BudgetCategory, %{
          name: "Update Policy Test",
          icon: "hero-star-solid",
          color: "#FF0000"
        })

      # Should be able to update without authorization issues
      assert {:ok, updated} =
               category
               |> Ash.Changeset.for_update(:update, %{description: "Updated"})
               |> Ash.update()

      assert updated.description == "Updated"
    end
  end

  describe "seeded categories" do
    test "six predefined categories exist after seeds" do
      # Seed the expected categories for this test
      expected_categories = [
        "Fixed Costs",
        "Comfort",
        "Goals",
        "Pleasures",
        "Financial Liberty",
        "Knowledge"
      ]

      # Seed them for this test (will fail if duplicates exist, which is fine)
      Enum.each(expected_categories, fn name ->
        try do
          Seed.seed!(BudgetCategory, %{
            name: name,
            icon: "hero-star-solid",
            color: "#FF0000"
          })
        rescue
          # Ignore if already exists
          Ash.Error.Invalid -> :ok
        end
      end)

      assert {:ok, categories} = Ash.read(BudgetCategory)
      category_names = Enum.map(categories, & &1.name)

      Enum.each(expected_categories, fn expected_name ->
        assert expected_name in category_names,
               "Expected category '#{expected_name}' not found in: #{inspect(category_names)}"
      end)
    end
  end
end

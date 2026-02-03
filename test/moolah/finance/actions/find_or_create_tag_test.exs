defmodule Moolah.Finance.Actions.FindOrCreateTagTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Finance.Tag

  describe "FindOrCreateTag action" do
    test "creates a new tag when none exists" do
      # Use the find_or_create action
      changeset =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "New Tag",
          color: "#22C55E"
        })

      assert {:ok, tag} = Ash.create(changeset)
      assert to_string(tag.name) == "New Tag"
      assert tag.color == "#22C55E"
    end

    test "returns existing tag when tag with same name exists" do
      # Create a tag first
      {:ok, existing_tag} =
        Tag
        |> Ash.Changeset.for_create(:create, %{
          name: "Existing Tag",
          color: "#3B82F6"
        })
        |> Ash.create()

      # Try to find_or_create with the same name
      changeset =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Existing Tag",
          color: "#EF4444"
        })

      assert {:ok, tag} = Ash.create(changeset)
      # Should return the existing tag, not create a new one
      assert tag.id == existing_tag.id
      # Color should be from the existing tag, not the new attempt
      assert tag.color == "#3B82F6"
    end

    test "returns existing tag with case-insensitive name match" do
      # Create a tag with specific casing
      {:ok, existing_tag} =
        Tag
        |> Ash.Changeset.for_create(:create, %{
          name: "Travel",
          color: "#3B82F6"
        })
        |> Ash.create()

      # Try to find_or_create with different casing
      changeset =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "TRAVEL",
          color: "#EF4444"
        })

      assert {:ok, tag} = Ash.create(changeset)
      # Should return the existing tag (case-insensitive match)
      assert tag.id == existing_tag.id
    end

    test "creates tag with optional description" do
      changeset =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Work",
          color: "#22C55E",
          description: "Work-related expenses"
        })

      assert {:ok, tag} = Ash.create(changeset)
      assert to_string(tag.name) == "Work"
      assert tag.description == "Work-related expenses"
    end

    test "finds existing tag ignoring description differences" do
      # Create tag with description
      {:ok, existing_tag} =
        Tag
        |> Ash.Changeset.for_create(:create, %{
          name: "Shopping",
          color: "#3B82F6",
          description: "Shopping expenses"
        })
        |> Ash.create()

      # Try to find_or_create with same name but different description
      changeset =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Shopping",
          color: "#EF4444",
          description: "Different description"
        })

      assert {:ok, tag} = Ash.create(changeset)
      # Should return existing tag
      assert tag.id == existing_tag.id
      # Description should be from existing tag
      assert tag.description == "Shopping expenses"
    end

    test "creates different tags with different names" do
      {:ok, tag1} =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Food",
          color: "#22C55E"
        })
        |> Ash.create()

      {:ok, tag2} =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Travel",
          color: "#3B82F6"
        })
        |> Ash.create()

      # Should create two different tags
      assert tag1.id != tag2.id
      assert to_string(tag1.name) == "Food"
      assert to_string(tag2.name) == "Travel"
    end

    test "handles whitespace normalization before finding" do
      # Create tag with normalized name
      {:ok, existing_tag} =
        Tag
        |> Ash.Changeset.for_create(:create, %{
          name: "Work Travel",
          color: "#3B82F6"
        })
        |> Ash.create()

      # Try to find_or_create with extra whitespace (should normalize to same)
      changeset =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "  Work   Travel  ",
          color: "#EF4444"
        })

      assert {:ok, tag} = Ash.create(changeset)
      # Should find the existing tag after normalization
      assert tag.id == existing_tag.id
    end

    test "respects unique constraint on name" do
      # Create a tag
      {:ok, _existing_tag} =
        Tag
        |> Ash.Changeset.for_create(:create, %{
          name: "Unique",
          color: "#3B82F6"
        })
        |> Ash.create()

      # Regular create should fail due to unique constraint
      changeset =
        Tag
        |> Ash.Changeset.for_create(:create, %{
          name: "Unique",
          color: "#EF4444"
        })

      assert {:error, _error} = Ash.create(changeset)
    end

    test "validates required fields" do
      # Name is required
      changeset =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          color: "#22C55E"
        })

      assert {:error, error} = Ash.create(changeset)
      assert %Ash.Error.Invalid{} = error
    end

    test "works with multiple concurrent calls for same tag" do
      # This tests idempotency - calling find_or_create multiple times
      # should always return the same tag
      {:ok, tag1} =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Concurrent",
          color: "#22C55E"
        })
        |> Ash.create()

      {:ok, tag2} =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Concurrent",
          color: "#3B82F6"
        })
        |> Ash.create()

      {:ok, tag3} =
        Tag
        |> Ash.Changeset.for_create(:find_or_create, %{
          name: "Concurrent",
          color: "#EF4444"
        })
        |> Ash.create()

      # All should return the same tag
      assert tag1.id == tag2.id
      assert tag2.id == tag3.id
    end
  end
end

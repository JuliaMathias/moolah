defmodule Moolah.Finance.Changes.GenerateTagSlugTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Ash.Changeset
  alias Moolah.Finance.Changes.GenerateTagSlug
  alias Moolah.Finance.Tag

  describe "generate_tag_slug change" do
    test "generates lowercase slug from simple name" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Travel"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "travel"
    end

    test "replaces spaces with hyphens" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Work From Home"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "work-from-home"
    end

    test "removes special characters" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Food & Drinks!"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "food-drinks"
    end

    test "normalizes accented characters" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Café"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "cafe"
    end

    test "trims leading and trailing hyphens" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "---Test---"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "test"
    end

    test "collapses multiple hyphens into one" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Work---From---Home"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "work-from-home"
    end

    test "handles strings with leading/trailing whitespace" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "  Travel  "))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "travel"
    end

    test "adds error for strings that result in empty slug" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "!!!"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert changeset.errors != []

      assert Enum.any?(changeset.errors, fn e ->
               e.field == :slug && to_string(e.message) =~ "must be present"
             end)
    end

    test "adds error for special-characters-only strings" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "@#$%^&*()"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert changeset.errors != []

      assert Enum.any?(changeset.errors, fn e ->
               e.field == :slug
             end)
    end

    test "handles nil source values gracefully" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, nil))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      # Should not modify or add errors for nil
      assert Changeset.get_attribute(changeset, :slug) == nil
      assert changeset.errors == []
    end

    test "handles Ash.CiString source values" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, Ash.CiString.new("Hello World")))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "hello-world"
    end

    test "adds error for Ash.CiString that results in empty slug" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, Ash.CiString.new("@@@")))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert changeset.errors != []

      assert Enum.any?(changeset.errors, fn e ->
               e.field == :slug
             end)
    end

    test "handles numbers in names" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Project 2024"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "project-2024"
    end

    test "handles mixed case with numbers and special chars" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Team-Building 2024!"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "team-building-2024"
    end

    test "handles complex unicode normalization" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Niño José"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "nino-jose"
    end

    test "preserves hyphens in original name" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Multi-Part Name"))
        |> GenerateTagSlug.change([source: :name, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "multi-part-name"
    end

    test "works with custom source field via opts" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :description, "Custom Field"))
        |> GenerateTagSlug.change([source: :description, target: :slug], %{})

      assert Changeset.get_attribute(changeset, :slug) == "custom-field"
    end

    test "integration: works in full create changeset" do
      changeset =
        Tag
        |> Changeset.for_create(:create, %{
          name: "Work Travel",
          color: "#22C55E"
        })

      # The change should be applied as part of the action
      assert {:ok, tag} = Ash.create(changeset)
      assert tag.slug == "work-travel"
    end

    test "integration: combines with normalize_tag_name" do
      # If normalize runs first, it should clean up the name
      # Then slug generation should work on the normalized name
      changeset =
        Tag
        |> Changeset.for_create(:create, %{
          name: "  Work   From   Home  ",
          color: "#22C55E"
        })

      assert {:ok, tag} = Ash.create(changeset)
      # Name should be normalized to "Work From Home"
      # Slug should be "work-from-home"
      assert to_string(tag.name) == "Work From Home"
      assert tag.slug == "work-from-home"
    end
  end
end

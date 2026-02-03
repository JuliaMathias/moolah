defmodule Moolah.Finance.Changes.NormalizeTagNameTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Ash.Changeset
  alias Moolah.Finance.Changes.NormalizeTagName
  alias Moolah.Finance.Tag

  describe "NormalizeTagName change" do
    test "trims leading and trailing whitespace" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "  Travel  "))
        |> NormalizeTagName.change([field: :name], %{})

      assert to_string(Changeset.get_attribute(changeset, :name)) == "Travel"
    end

    test "collapses multiple whitespaces into single space" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Work   From    Home"))
        |> NormalizeTagName.change([field: :name], %{})

      assert to_string(Changeset.get_attribute(changeset, :name)) == "Work From Home"
    end

    test "handles mixed whitespace types (spaces, tabs, newlines)" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "  Food\t\n  Shopping  "))
        |> NormalizeTagName.change([field: :name], %{})

      assert to_string(Changeset.get_attribute(changeset, :name)) == "Food Shopping"
    end

    test "preserves already normalized strings" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "Vacation"))
        |> NormalizeTagName.change([field: :name], %{})

      assert to_string(Changeset.get_attribute(changeset, :name)) == "Vacation"
    end

    test "adds error for whitespace-only strings" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "   "))
        |> NormalizeTagName.change([field: :name], %{})

      assert changeset.errors != []

      assert Enum.any?(changeset.errors, fn e ->
               e.field == :name && to_string(e.message) =~ "must be present"
             end)
    end

    test "adds error for empty strings" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, ""))
        |> NormalizeTagName.change([field: :name], %{})

      assert changeset.errors != []

      assert Enum.any?(changeset.errors, fn e ->
               e.field == :name && to_string(e.message) =~ "must be present"
             end)
    end

    test "handles nil values gracefully" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, nil))
        |> NormalizeTagName.change([field: :name], %{})

      # Should not modify or add errors for nil
      assert Changeset.get_attribute(changeset, :name) == nil
      assert changeset.errors == []
    end

    test "handles Ash.CiString values" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, Ash.CiString.new("  Work  Travel  ")))
        |> NormalizeTagName.change([field: :name], %{})

      assert to_string(Changeset.get_attribute(changeset, :name)) == "Work Travel"
    end

    test "adds error for whitespace-only Ash.CiString" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, Ash.CiString.new("   ")))
        |> NormalizeTagName.change([field: :name], %{})

      assert changeset.errors != []

      assert Enum.any?(changeset.errors, fn e ->
               e.field == :name && to_string(e.message) =~ "must be present"
             end)
    end

    test "leaves non-string values unchanged" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, 12345))
        |> NormalizeTagName.change([field: :name], %{})

      # Non-strings should pass through unchanged
      assert Changeset.get_attribute(changeset, :name) == 12345
      assert changeset.errors == []
    end

    test "handles unicode characters correctly" do
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :name, "  Café   Société  "))
        |> NormalizeTagName.change([field: :name], %{})

      assert to_string(Changeset.get_attribute(changeset, :name)) == "Café Société"
    end

    test "works with different field names via opts" do
      # The change accepts a :field option
      changeset =
        Tag
        |> Changeset.new()
        |> Map.update!(:attributes, &Map.put(&1, :description, "  Test   Description  "))
        |> NormalizeTagName.change([field: :description], %{})

      assert to_string(Changeset.get_attribute(changeset, :description)) == "Test Description"
    end

    test "integration: works in full create changeset" do
      changeset =
        Tag
        |> Changeset.for_create(:create, %{
          name: "  Work   Travel  ",
          color: "#22C55E"
        })

      # The change should be applied as part of the action
      assert {:ok, tag} = Ash.create(changeset)
      assert to_string(tag.name) == "Work Travel"
    end
  end
end

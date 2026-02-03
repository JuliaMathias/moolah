defmodule Moolah.Finance.TagTest do
  @moduledoc """
  Tests for the Tag resource.
  """

  use Moolah.DataCase, async: true

  alias Moolah.Finance.Tag

  test "normalizes name and generates slug" do
    assert {:ok, tag} =
             Tag
             |> Ash.Changeset.for_create(:create, %{
               name: "  Food   & Drinks  ",
               color: "#22C55E"
             })
             |> Ash.create()

    assert to_string(tag.name) == "Food & Drinks"
    assert tag.slug == "food-drinks"
  end

  test "validates color format" do
    assert {:error, %Ash.Error.Invalid{}} =
             Tag
             |> Ash.Changeset.for_create(:create, %{
               name: "Invalid Color",
               color: "red"
             })
             |> Ash.create()
  end

  test "enforces case-insensitive name uniqueness" do
    assert {:ok, _tag} =
             Tag
             |> Ash.Changeset.for_create(:create, %{
               name: "Travel",
               color: "#3B82F6"
             })
             |> Ash.create()

    assert {:error, %Ash.Error.Invalid{}} =
             Tag
             |> Ash.Changeset.for_create(:create, %{
               name: "travel",
               color: "#3B82F6"
             })
             |> Ash.create()
  end

  test "find_or_create returns existing tag when name matches" do
    assert {:ok, tag} =
             Tag
             |> Ash.Changeset.for_create(:find_or_create, %{
               name: "Groceries",
               color: "#22C55E"
             })
             |> Ash.create()

    assert {:ok, matched} =
             Tag
             |> Ash.Changeset.for_create(:find_or_create, %{
               name: "Groceries",
               color: "#EF4444"
             })
             |> Ash.create()

    assert matched.id == tag.id
  end

  test "find_or_create does not resurrect archived tags" do
    assert {:ok, tag} =
             Tag
             |> Ash.Changeset.for_create(:create, %{
               name: "Archived Find",
               color: "#F59E0B"
             })
             |> Ash.create()

    assert :ok = Ash.destroy(tag)

    assert {:error, %Ash.Error.Invalid{}} =
             Tag
             |> Ash.Changeset.for_create(:find_or_create, %{
               name: "Archived Find",
               color: "#F59E0B"
             })
             |> Ash.create()
  end

  test "soft deletes tags and excludes them from default read" do
    assert {:ok, tag} =
             Tag
             |> Ash.Changeset.for_create(:create, %{
               name: "Archived",
               color: "#F59E0B"
             })
             |> Ash.create()

    assert :ok = Ash.destroy(tag)

    assert {:ok, tags} = Ash.read(Tag)
    refute Enum.any?(tags, &(&1.id == tag.id))

    assert {:ok, archived} = Ash.read(Tag, action: :including_archived)
    assert Enum.any?(archived, &(&1.id == tag.id))
  end
end

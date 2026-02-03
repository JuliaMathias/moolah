defmodule Moolah.Finance.Changes.TagChangeUnitTest do
  @moduledoc """
  Unit tests for tag change modules to cover edge branches.
  """

  use Moolah.DataCase, async: true

  alias Ash.Resource.ManualCreate.Context
  alias Moolah.Finance.Actions.FindOrCreateTag
  alias Moolah.Finance.Changes.GenerateTagSlug
  alias Moolah.Finance.Changes.ManageTransactionTags
  alias Moolah.Finance.Changes.NormalizeTagName
  alias Moolah.Finance.Tag
  alias Moolah.Finance.Transaction

  test "normalize_tag_name handles binary values and leaves non-strings untouched" do
    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Map.update!(:attributes, &Map.put(&1, :name, "  Work  Travel "))
      |> NormalizeTagName.change([field: :name], %{})

    assert to_string(Ash.Changeset.get_attribute(changeset, :name)) == "Work Travel"

    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Map.update!(:attributes, &Map.put(&1, :name, 123))
      |> NormalizeTagName.change([field: :name], %{})

    assert Ash.Changeset.get_attribute(changeset, :name) == 123
  end

  test "normalize_tag_name adds errors for blank ci_string and blank binary" do
    changeset =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "   ", color: "#22C55E"})
      |> NormalizeTagName.change([field: :name], %{})

    assert changeset.errors != []

    changeset =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "   ", color: "#22C55E"})
      |> Ash.Changeset.force_change_attribute(:name, Ash.CiString.new("   "))
      |> NormalizeTagName.change([field: :name], %{})

    assert changeset.errors != []

    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Map.update!(:attributes, &Map.put(&1, :name, ""))
      |> NormalizeTagName.change([field: :name], %{})

    assert changeset.errors != []

    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Map.update!(:attributes, &Map.put(&1, :name, Ash.CiString.new("")))
      |> NormalizeTagName.change([field: :name], %{})

    assert changeset.errors != []
  end

  test "generate_tag_slug handles binary and ci_string inputs with blank slugs" do
    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Map.update!(:attributes, &Map.put(&1, :name, "Hello World"))
      |> GenerateTagSlug.change([source: :name, target: :slug], %{})

    assert Ash.Changeset.get_attribute(changeset, :slug) == "hello-world"

    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Map.update!(:attributes, &Map.put(&1, :name, "!!!"))
      |> GenerateTagSlug.change([source: :name, target: :slug], %{})

    assert changeset.errors != []

    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Ash.Changeset.force_change_attribute(:name, Ash.CiString.new("!!!"))
      |> GenerateTagSlug.change([source: :name, target: :slug], %{})

    assert changeset.errors != []
  end

  test "find_or_create returns error when read fails" do
    changeset =
      Tag
      |> Ash.Changeset.new()
      |> Map.update!(:attributes, &Map.put(&1, :name, ["bad"]))

    context = %Context{
      domain: Moolah.Finance,
      actor: nil,
      tenant: nil,
      authorize?: false
    }

    assert {:error, _} = FindOrCreateTag.create(changeset, [], context)
  end

  test "manage_transaction_tags passes through non-list inputs" do
    changeset =
      Transaction
      |> Ash.Changeset.new()
      |> Map.update!(:arguments, &Map.put(&1, :tags, "oops"))
      |> ManageTransactionTags.change([], %{})

    assert Ash.Changeset.get_argument(changeset, :tags) == "oops"
    assert changeset.errors == []
  end
end

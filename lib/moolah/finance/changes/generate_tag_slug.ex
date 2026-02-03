defmodule Moolah.Finance.Changes.GenerateTagSlug do
  @moduledoc """
  Generates a URL-friendly slug from a tag name.

  The slug is derived from the source field, lowercased, normalized, and
  converted to hyphen-separated tokens.

  ## Examples

      actions do
        create :create do
          accept [:name]
          change {Moolah.Finance.Changes.GenerateTagSlug, source: :name, target: :slug}
        end
      end

      # Input -> Slug
      # "Food & Drinks" -> "food-drinks"
      # "  Café  " -> "cafe"
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @spec change(Changeset.t(), keyword(), map()) :: Changeset.t()
  @impl true
  def change(changeset, opts, _context) do
    source = Keyword.fetch!(opts, :source)
    target = Keyword.fetch!(opts, :target)

    case Changeset.get_attribute(changeset, source) do
      nil ->
        changeset

      value when is_binary(value) ->
        slug = slugify(value)

        if slug == "" do
          Changeset.add_error(changeset, field: target, message: "must be present")
        else
          Changeset.force_change_attribute(changeset, target, slug)
        end
    end
  end

  @spec slugify(String.t()) :: String.t()
  defp slugify(value) do
    value
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/\s+/u, "-")
    |> String.replace(~r/-+/u, "-")
    |> String.trim("-")
  end
end

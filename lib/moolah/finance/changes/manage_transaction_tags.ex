defmodule Moolah.Finance.Changes.ManageTransactionTags do
  @moduledoc """
  Manages transaction tag relationships when tag inputs are provided.

  Expects a `:tags` argument on the action with a list of maps, e.g.
  `%{name: "Groceries", color: "#22C55E"}`. This change will:

  - Create tags on-demand using `Tag.find_or_create` (ignores archived tags)
  - Relate existing tags by identity (case-insensitive name or slug)
  - Replace existing tag set with the provided list (append and remove)

  ## Examples

      actions do
        create :create do
          argument :tags, {:array, :map}
          change Moolah.Finance.Changes.ManageTransactionTags
        end
      end

      # Usage
      Moolah.Finance.Transaction
      |> Ash.Changeset.for_create(:create, %{
        transaction_type: :debit,
        account_id: account_id,
        budget_category_id: budget_id,
        life_area_category_id: life_area_id,
        amount: Money.new(25, :BRL),
        tags: [
          %{name: "Groceries", color: "#22C55E"},
          %{name: "Weekend"}
        ]
      })
      |> Ash.create()
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @spec change(Changeset.t(), keyword(), map()) :: Changeset.t()
  @impl true
  def change(changeset, _opts, _context) do
    case Changeset.get_argument(changeset, :tags) do
      nil ->
        changeset

      tags ->
        tags = dedupe_tags(tags)

        Changeset.manage_relationship(
          changeset,
          :tags,
          tags,
          type: :append_and_remove,
          on_no_match: {:create, :find_or_create},
          on_lookup: :relate,
          use_identities: [:unique_name, :unique_slug],
          error_path: :tags
        )
    end
  end

  @spec dedupe_tags(list() | term()) :: list() | term()
  defp dedupe_tags(tags) when is_list(tags) do
    tags
    |> Enum.reduce({MapSet.new(), []}, fn tag, {seen, acc} ->
      key = dedupe_key(tag)

      if MapSet.member?(seen, key) do
        {seen, acc}
      else
        {MapSet.put(seen, key), [tag | acc]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp dedupe_tags(tags), do: tags

  @spec dedupe_key(map()) :: {:id, term()} | {:slug, String.t()} | {:name, String.t()} | {:unknown, reference()}
  defp dedupe_key(%{id: id}) when not is_nil(id), do: {:id, id}
  defp dedupe_key(%{"id" => id}) when not is_nil(id), do: {:id, id}

  defp dedupe_key(%{slug: slug}) when is_binary(slug), do: {:slug, String.downcase(slug)}
  defp dedupe_key(%{"slug" => slug}) when is_binary(slug), do: {:slug, String.downcase(slug)}

  defp dedupe_key(%{name: name}) when is_binary(name), do: {:name, String.downcase(name)}
  defp dedupe_key(%{"name" => name}) when is_binary(name), do: {:name, String.downcase(name)}

  defp dedupe_key(_), do: {:unknown, make_ref()}
end

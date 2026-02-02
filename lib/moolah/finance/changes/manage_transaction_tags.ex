defmodule Moolah.Finance.Changes.ManageTransactionTags do
  @moduledoc """
  Manages transaction tag relationships when tag inputs are provided.

  Expects a `:tags` argument on the action with a list of maps, e.g.
  `%{name: "Groceries", color: "#22C55E"}`. This change will:

  - Create tags on-demand using `Tag.find_or_create`
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
end

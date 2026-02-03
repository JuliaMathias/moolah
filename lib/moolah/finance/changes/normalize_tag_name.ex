defmodule Moolah.Finance.Changes.NormalizeTagName do
  @moduledoc """
  Normalizes tag names by trimming and collapsing whitespace.

  This change is intended for use in Tag create/update actions to ensure
  consistent name storage and to prevent whitespace-only values.

  ## Examples

      actions do
        create :create do
          accept [:name, :color]
          change {Moolah.Finance.Changes.NormalizeTagName, field: :name}
        end
      end

      # Input -> Stored
      # "  Work   Travel " -> "Work Travel"
  """

  use Ash.Resource.Change

  alias Ash.Changeset

  @spec change(Changeset.t(), keyword(), map()) :: Changeset.t()
  @impl true
  def change(changeset, opts, _context) do
    field = Keyword.fetch!(opts, :field)

    case Changeset.get_attribute(changeset, field) do
      nil ->
        changeset

      value when is_binary(value) ->
        normalized =
          value
          |> String.trim()
          |> String.replace(~r/\s+/u, " ")

        if normalized == "" do
          Changeset.add_error(changeset, field: field, message: "must be present")
        else
          Changeset.force_change_attribute(changeset, field, normalized)
        end

      value when is_struct(value, Ash.CiString) ->
        normalized =
          value
          |> to_string()
          |> String.trim()
          |> String.replace(~r/\s+/u, " ")

        if normalized == "" do
          Changeset.add_error(changeset, field: field, message: "must be present")
        else
          Changeset.force_change_attribute(changeset, field, normalized)
        end

      _ ->
        changeset
    end
  end
end

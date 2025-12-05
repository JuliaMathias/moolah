defmodule Moolah.Finance.Validations.NoCycleReference do
  @moduledoc """
  Validates that a category does not create a circular reference in the parent hierarchy.

  Prevents situations like:
  - Category cannot be its own parent (self-reference)
  - Category A → B → A (circular reference)
  - Category A → B → C → A (deeper circular reference)

  ## Usage

      validations do
        validate {Moolah.Finance.Validations.NoCycleReference, []}
      end
  """

  use Ash.Resource.Validation

  @impl true
  @spec init(keyword()) :: {:ok, keyword()}
  def init(opts), do: {:ok, opts}

  @impl true
  @spec supports(keyword()) :: [module()]
  def supports(_opts), do: [Ash.Changeset]

  @doc """
  Validates that the category does not create a circular reference.

  ## Parameters
  - changeset: The changeset being validated
  - _opts: Validation options (unused)
  - _context: The validation context (unused)

  ## Returns
  - `:ok` if no circular reference detected
  - `{:error, keyword()}` with error details if circular reference found
  """
  @impl true
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)
    category_id = Ash.Changeset.get_attribute(changeset, :id)

    cond do
      # No parent means root category, always valid
      is_nil(parent_id) ->
        :ok

      # Prevent self-reference (category cannot be its own parent)
      parent_id == category_id ->
        {:error, field: :parent_id, message: "cannot be the same as the category itself"}

      # Check for cycles by walking up the parent chain
      true ->
        check_for_cycle(parent_id, category_id, changeset.resource)
    end
  end

  # Recursively walk up the parent chain to detect cycles
  @spec check_for_cycle(String.t() | nil, String.t(), module()) :: :ok | {:error, keyword()}
  defp check_for_cycle(nil, _original_id, _resource), do: :ok

  @spec check_for_cycle(String.t(), String.t(), module()) :: :ok | {:error, keyword()}
  defp check_for_cycle(parent_id, original_id, resource) do
    case Ash.get(resource, parent_id) do
      {:ok, parent} ->
        # Found a cycle: parent eventually points back to original category
        if parent.id == original_id do
          {:error, field: :parent_id, message: "creates a circular reference"}
        else
          # Continue walking up the chain
          check_for_cycle(parent.parent_id, original_id, resource)
        end

      {:error, _} ->
        {:error, field: :parent_id, message: "parent category not found"}
    end
  end
end

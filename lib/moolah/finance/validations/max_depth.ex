defmodule Moolah.Finance.Validations.MaxDepth do
  @moduledoc """
  Validates that a category does not exceed the maximum hierarchy depth.

  For LifeAreaCategory, we enforce a maximum depth of 2 levels:
  - Level 0: Root categories (no parent)
  - Level 1: Child categories (one parent)
  - Level 2+: Not allowed (no grandchildren)

  ## Usage

      validations do
        validate {Moolah.Finance.Validations.MaxDepth, max_depth: 2}
      end
  """

  use Ash.Resource.Validation

  @impl true
  @spec init(keyword()) :: {:ok, keyword()}
  def init(opts) do
    max_depth = Keyword.get(opts, :max_depth, 2)
    {:ok, Keyword.put(opts, :max_depth, max_depth)}
  end

  @impl true
  @spec supports(keyword()) :: [module()]
  def supports(_opts), do: [Ash.Changeset]

  @doc """
  Validates that the category does not exceed maximum hierarchy depth.

  ## Parameters
  - changeset: The changeset being validated
  - opts: Validation options including `:max_depth` (defaults to 2)
  - _context: The validation context (unused)

  ## Returns
  - `:ok` if depth is within limits
  - `{:error, keyword()}` with error details if depth exceeds maximum
  """
  @impl true
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, opts, _context) do
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)
    max_depth = opts[:max_depth]

    case calculate_depth(parent_id, changeset.resource, 1) do
      depth when depth >= max_depth ->
        {:error,
         field: :parent_id,
         message: "would create depth #{depth}, but maximum allowed is #{max_depth - 1}"}

      _ ->
        :ok
    end
  end

  # Calculate depth by walking up the parent chain
  # Depth 0 = root (no parent)
  # Depth 1 = child (parent is root)
  # Depth 2 = grandchild (parent has a parent)

  @spec calculate_depth(String.t() | nil, module(), non_neg_integer()) :: non_neg_integer()
  defp calculate_depth(nil, _resource, current_depth) do
    # Reached root, depth is current - 1
    current_depth - 1
  end

  @spec calculate_depth(String.t(), module(), non_neg_integer()) :: non_neg_integer()
  defp calculate_depth(parent_id, resource, current_depth) do
    case Ash.get(resource, parent_id) do
      {:ok, parent} ->
        # Continue walking up the chain
        calculate_depth(parent.parent_id, resource, current_depth + 1)

      {:error, _} ->
        # Parent not found, consider depth 0 (shouldn't happen with valid data)
        0
    end
  end
end

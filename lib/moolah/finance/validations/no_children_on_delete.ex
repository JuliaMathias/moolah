defmodule Moolah.Finance.Validations.NoChildrenOnDelete do
  @moduledoc """
  Prevents deletion of a category that has child categories.

  This ensures data integrity by requiring users to delete or reassign
  child categories before deleting the parent.

  ## Usage

      validations do
        validate {Moolah.Finance.Validations.NoChildrenOnDelete, []} do
          where action_type(:destroy)
        end
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
  Validates that a category has no children before allowing deletion.

  ## Parameters
  - changeset: The changeset being validated (for destroy action)
  - _opts: Validation options (unused)
  - _context: The validation context (unused)

  ## Returns
  - `:ok` if category has no children
  - `{:error, keyword()}` with error details if category has children
  """
  @impl true
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    # Get the category being deleted
    category = changeset.data

    # Check if this category has any children
    case count_children(category.id, changeset.resource) do
      {:ok, 0} ->
        # No children, safe to delete
        :ok

      {:ok, count} ->
        # Has children, prevent deletion
        {:error,
         field: :id,
         message:
           "cannot delete category that has #{count} child #{pluralize(count, "category", "categories")}"}

      {:error, reason} ->
        {:error, field: :id, message: "error checking for children: #{inspect(reason)}"}
    end
  end

  @spec count_children(String.t(), module()) :: {:ok, non_neg_integer()} | {:error, term()}
  defp count_children(category_id, resource) do
    resource
    |> Ash.Query.filter(parent_id == ^category_id)
    |> Ash.count()
  end

  @spec pluralize(non_neg_integer(), String.t(), String.t()) :: String.t()
  defp pluralize(1, singular, _plural), do: singular

  @spec pluralize(non_neg_integer(), String.t(), String.t()) :: String.t()
  defp pluralize(_, _singular, plural), do: plural
end

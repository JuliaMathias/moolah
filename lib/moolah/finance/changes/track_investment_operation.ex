defmodule Moolah.Finance.Changes.TrackInvestmentOperation do
  @moduledoc """
  Creates an investment operation when the current value changes.

  This is used to track delta updates over time in a consistent way.

  ## Examples

      actions do
        update :update do
          change Moolah.Finance.Changes.TrackInvestmentOperation
        end
      end
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Moolah.Finance.InvestmentOperation

  @impl true
  @spec change(Changeset.t(), keyword(), map()) :: Changeset.t()
  def change(changeset, _opts, _context) do
    if Changeset.changing_attribute?(changeset, :current_value) do
      Changeset.after_action(changeset, fn _changeset, record ->
        create_operation(changeset, record)
      end)
    else
      changeset
    end
  end

  @spec create_operation(Changeset.t(), Ash.Resource.record()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_operation(changeset, record) do
    # Compute the delta between the previous and current values.
    old_value = changeset.data.current_value
    new_value = record.current_value

    with {:ok, delta} <- Money.sub(new_value, old_value),
         {:ok, _operation} <- insert_operation(record.id, delta) do
      {:ok, record}
    else
      {:error, error} -> {:error, error}
    end
  end

  @spec insert_operation(Ecto.UUID.t(), Money.t()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp insert_operation(investment_id, delta) do
    InvestmentOperation
    |> Ash.Changeset.for_create(:create, %{
      investment_id: investment_id,
      type: :update,
      value: delta
    })
    |> Ash.create()
  end
end

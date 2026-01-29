defmodule Moolah.Finance.Changes.UpdateUnderlyingTransfer do
  @moduledoc """
  This module defines an Ash Resource Change, which is a hook that runs during the
  lifecycle of a resource action (create, update, or destroy).

  In this specific context, when a high-level `Transaction` is updated (e.g., amount changed),
  this Change ensures that the low-level `Moolah.Ledger.Transfer` is also updated to match.
  This guarantees that our user-facing transaction history and our double-entry ledger always
  stay strictly closely synchronized.
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Moolah.Finance.Changes.CreateUnderlyingTransfer

  @type changeset :: Ash.Changeset.t()

  @doc """
  Callback for the Ash.Resource.Change behaviour.
  Handles updates to the transaction that should propagate to the ledger.
  """
  @spec change(changeset(), keyword(), map()) :: changeset()
  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_transaction(changeset, fn changeset ->
      # Only process if amount, date, or category/account changed
      if Changeset.changing_attribute?(changeset, :amount) or
           Changeset.changing_attribute?(changeset, :source_amount) or
           Changeset.changing_attribute?(changeset, :date) or
           Changeset.changing_attribute?(changeset, :budget_category_id) or
           Changeset.changing_attribute?(changeset, :life_area_category_id) or
           Changeset.changing_attribute?(changeset, :account_id) or
           Changeset.changing_attribute?(changeset, :target_account_id) do
        update_transfer(changeset)
      else
        changeset
      end
    end)
  end

  @spec update_transfer(changeset()) :: changeset()
  defp update_transfer(changeset) do
    # Implementation strategy:
    # 1. Create a NEW underlying transfer with the new values (using sibling module)
    # 2. Update the transaction changeset to point to the new transfer_id
    # 3. Queue destruction of the OLD transfer in an `after_action` hook
    #    (This runs after the DB update has safely swapped the ID, preventing FK violations)

    # 1. Create new transfer
    case CreateUnderlyingTransfer.create_transfer_for_transaction(changeset) do
      {:ok, new_transfer} ->
        # Capture old ID before we overwrite it in the changeset
        old_transfer_id = changeset.data.transfer_id

        changeset
        # 2. Update pointer
        |> Changeset.force_change_attribute(:transfer_id, new_transfer.id)
        # 3. Queue destroy
        |> Changeset.after_action(fn _changeset, result ->
          case destroy_old_transfer(old_transfer_id) do
            :ok -> {:ok, result}
            {:error, error} -> {:error, error}
          end
        end)

      {:error, error} ->
        Changeset.add_error(changeset, error)
    end
  end

  @spec destroy_old_transfer(Ecto.UUID.t() | nil) :: :ok | {:error, any()}
  defp destroy_old_transfer(nil), do: :ok

  defp destroy_old_transfer(transfer_id) do
    Moolah.Ledger.Transfer
    |> Ash.Query.filter(id == ^transfer_id)
    |> Ash.read_one()
    |> case do
      {:ok, transfer} when not is_nil(transfer) ->
        Ash.destroy(transfer)

      {:ok, nil} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end
end

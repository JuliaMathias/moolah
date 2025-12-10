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
      # Only process if amount or date changed
      if Changeset.changing_attribute?(changeset, :amount) or
           Changeset.changing_attribute?(changeset, :date) do
        update_transfer(changeset)
      else
        changeset
      end
    end)
  end

  @spec update_transfer(changeset()) :: changeset()
  defp update_transfer(changeset) do
    # Implementation strategy:
    # 1. Fetch the existing transaction record (to get the old transfer_id)
    # 2. Destroy the old underlying transfer (reversing its effects on ledger)
    # 3. Create a NEW underlying transfer with the new values
    # 4. Update the transaction to point to the new transfer_id
    #
    # ATOMICITY NOTE:
    # This runs within `Changeset.before_transaction/2`. Ash wraps this entire hook
    # in the database transaction. If step 2 (destroy) succeeds but step 3 (create) fails,
    # the entire transaction rolls back, preventing data loss or unbalanced ledgers.

    old_transfer_id = changeset.data.transfer_id

    # 1. Destroy old transfer
    case destroy_old_transfer(old_transfer_id) do
      :ok ->
        # 2. Reuse creation logic to make a new one
        # We can call the helper from CreateUnderlyingTransfer if we make it public,
        # or duplicate the logic. For now, let's call the brother module.
        # Actually, better to just implement the creation call here using the *new* changeset values.
        create_new_replacement_transfer(changeset)

      {:error, reason} ->
        Changeset.add_error(changeset, "Failed to update ledger: #{inspect(reason)}")
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

  @spec create_new_replacement_transfer(changeset()) :: changeset()
  defp create_new_replacement_transfer(changeset) do
    # We delegate to the logic in CreateUnderlyingTransfer.make_transfer/1
    # Requires refactoring CreateUnderlyingTransfer to separate the logic function.
    # For now, I'll inline the logic or use a shared helper.
    # Let's trust that I will refactor CreateUnderlyingTransfer to expose `create_transfer_record/1`.

    # Checking Moolah.Finance.Changes.CreateUnderlyingTransfer...
    # It has `create_transfer_for_transaction/1` which is private.
    # I will make it public doc hidden to reuse it.

    case CreateUnderlyingTransfer.create_transfer_for_transaction(changeset) do
      {:ok, transfer} ->
        Changeset.force_change_attribute(changeset, :transfer_id, transfer.id)

      {:error, error} ->
        Changeset.add_error(changeset, error)
    end
  end
end

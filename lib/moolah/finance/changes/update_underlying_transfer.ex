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
    # 1. Create NEW underlying transfer(s) (could be map or single transfer)
    # 2. Update the transaction changeset to point to the new IDs
    # 3. Queue destruction of the OLD transfer(s)

    case CreateUnderlyingTransfer.create_transfer_for_transaction(changeset) do
      {:ok, result, notifications} ->
        # Capture old IDs before we overwrite them in the changeset
        old_transfer_id = changeset.data.transfer_id
        old_source_transfer_id = changeset.data.source_transfer_id

        changeset =
          case result do
            %{source_transfer: s, target_transfer: t, exchange_rate: rate} ->
              changeset
              |> Changeset.force_change_attribute(:source_transfer_id, s.id)
              |> Changeset.force_change_attribute(:transfer_id, t.id)
              |> Changeset.force_change_attribute(:exchange_rate, rate)

            transfer ->
              changeset
              |> Changeset.force_change_attribute(:transfer_id, transfer.id)
              |> Changeset.force_change_attribute(:source_transfer_id, nil)
              |> Changeset.force_change_attribute(:exchange_rate, nil)
          end

        # Queue destroy of old transfers and send all notifications
        changeset
        |> Changeset.after_action(fn _changeset, final_result ->
          # Destroy both old legs if they exist
          with {:ok, n1} <- destroy_and_get_notifications(old_transfer_id),
               {:ok, n2} <- destroy_and_get_notifications(old_source_transfer_id) do
            # notifications from CreateUnderlyingTransfer + notifications from destruction
            Ash.Notifier.notify(notifications ++ n1 ++ n2)
            {:ok, final_result}
          else
            {:error, error} -> {:error, error}
          end
        end)

      {:error, error} ->
        Changeset.add_error(changeset, error)
    end
  end

  @spec destroy_and_get_notifications(AshDoubleEntry.ULID.t() | nil) ::
          {:ok, [Ash.Notifier.Notification.t()]} | {:error, any()}
  defp destroy_and_get_notifications(nil), do: {:ok, []}

  defp destroy_and_get_notifications(transfer_id) do
    Moolah.Ledger.Transfer
    |> Ash.Query.filter(id == ^transfer_id)
    |> Ash.read_one()
    |> case do
      {:ok, transfer} when not is_nil(transfer) ->
        case Ash.destroy(transfer, return_notifications?: true) do
          :ok -> {:ok, []}
          {:ok, notifications} -> {:ok, notifications}
          {:error, error} -> {:error, error}
        end

      {:ok, nil} ->
        {:ok, []}

      {:error, error} ->
        {:error, error}
    end
  end
end

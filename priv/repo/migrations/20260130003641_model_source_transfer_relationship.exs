defmodule Moolah.Repo.Migrations.ModelSourceTransferRelationship do
  @moduledoc """
  Enhances the referential integrity of multi-currency transactions.

  This migration converts the `source_transfer_id` on the `transactions` table from a
  raw binary field into a formal Foreign Key relationship pointing to `ledger_transfers`.
  It also adds a database index to improve performance when querying transaction history.
  """

  use Ecto.Migration

  def up do
    alter table(:transactions) do
      modify :source_transfer_id,
             references(:ledger_transfers,
               column: :id,
               name: "transactions_source_transfer_id_fkey",
               type: :binary,
               prefix: "public"
             )
    end

    create index(:transactions, [:source_transfer_id])
  end

  def down do
    drop_if_exists index(:transactions, [:source_transfer_id])

    drop_if_exists constraint(:transactions, "transactions_source_transfer_id_fkey")

    alter table(:transactions) do
      modify :source_transfer_id, :binary
    end
  end
end

defmodule Moolah.Repo.Migrations.AddUniqueInvestmentOperationsTransactionIdIndex do
  @moduledoc """
  Enforces a one-to-one relationship between investment operations and transactions.

  Investment operations generated from transfer transactions should map to a single
  transaction so reporting remains consistent and corrections to transfers can safely
  reconcile the existing operation. This migration adds a partial unique index on
  `investment_operations.transaction_id` (only when the value is present) to prevent
  duplicate operations from being persisted for the same transaction.

  This is intentionally a new migration rather than a modification of earlier
  migrations to keep the historical record intact.
  """

  use Ecto.Migration

  def up do
    create unique_index(:investment_operations, [:transaction_id],
             name: "investment_operations_unique_transaction_id",
             where: "transaction_id IS NOT NULL"
           )
  end

  def down do
    drop_if_exists index(:investment_operations, [:transaction_id],
                     name: "investment_operations_unique_transaction_id"
                   )
  end
end

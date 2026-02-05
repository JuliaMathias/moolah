defmodule Moolah.Repo.Migrations.DropInvestmentOperationsTransactionIdIndex do
  @moduledoc """
  Removes the redundant non-unique index on `investment_operations.transaction_id`.

  A later migration adds a partial unique index on the same column to enforce the
  one-to-one relationship between operations and transactions. Keeping both indexes
  adds write overhead without improving query performance, so we drop the original
  non-unique index while preserving the unique one.

  This is intentionally a new migration to keep the original historical change intact.
  """

  use Ecto.Migration

  def up do
    drop_if_exists index(:investment_operations, [:transaction_id],
                     name: "investment_operations_transaction_id_index"
                   )
  end

  def down do
    create index(:investment_operations, [:transaction_id],
             name: "investment_operations_transaction_id_index"
           )
  end
end

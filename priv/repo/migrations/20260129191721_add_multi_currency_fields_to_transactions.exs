defmodule Moolah.Repo.Migrations.AddMultiCurrencyFieldsToTransactions do
  @moduledoc """
  Adds `exchange_rate` and `source_transfer_id` columns to the `transactions` table.

  `source_transfer_id` is stored as `:binary` to match the `AshDoubleEntry.ULID`
  format used by the ledger system.
  """

  use Ecto.Migration

  def up do
    alter table(:transactions) do
      add :source_transfer_id, :binary
      add :exchange_rate, :decimal
    end
  end

  def down do
    alter table(:transactions) do
      remove :exchange_rate
      remove :source_transfer_id
    end
  end
end

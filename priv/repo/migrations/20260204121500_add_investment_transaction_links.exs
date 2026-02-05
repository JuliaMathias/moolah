defmodule Moolah.Repo.Migrations.AddInvestmentTransactionLinks do
  @moduledoc """
  Adds explicit links between transactions and investment operations.

  This migration supports the investment history/operations tracking work by:

  - Allowing transfer transactions to reference a specific investment via
    `transactions.target_investment_id` so operations can be tied to a concrete
    investment within an investment account.
  - Allowing investment operations to reference their originating transaction via
    `investment_operations.transaction_id` for auditability.

  These links enable precise attribution of deposit/withdraw operations to
  user-initiated transfers while keeping non-investment transfers untouched.
  """

  use Ecto.Migration

  def up do
    alter table(:transactions) do
      add :target_investment_id,
          references(:investments,
            column: :id,
            name: "transactions_target_investment_id_fkey",
            on_delete: :nilify_all,
            type: :uuid,
            prefix: "public"
          )
    end

    create index(:transactions, [:target_investment_id])

    alter table(:investment_operations) do
      add :transaction_id,
          references(:transactions,
            column: :id,
            name: "investment_operations_transaction_id_fkey",
            on_delete: :nilify_all,
            type: :uuid,
            prefix: "public"
          )
    end

    create index(:investment_operations, [:transaction_id])
  end

  def down do
    drop_if_exists index(:investment_operations, [:transaction_id])

    alter table(:investment_operations) do
      remove :transaction_id
    end

    drop_if_exists index(:transactions, [:target_investment_id])

    alter table(:transactions) do
      remove :target_investment_id
    end
  end
end

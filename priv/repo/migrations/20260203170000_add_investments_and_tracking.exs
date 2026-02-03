defmodule Moolah.Repo.Migrations.AddInvestmentsAndTracking do
  @moduledoc """
  Adds the core investments data model plus history and operation tracking tables.

  This migration introduces three new tables that underpin investment tracking in the
  Finance domain:

  - `investments`: a first-class record of an investment tied to a ledger investment
    account, including type/subtype, money values, and lifecycle dates
    (`purchase_date`, `redemption_date`).
  - `investment_histories`: dated snapshots of an investment's value used for
    time-series charts and historical reporting.
  - `investment_operations`: delta records for value changes, used to audit when and
    how an investment changed (e.g., updates, deposits, withdrawals).

  These structures are separate from the Ledger domain so we can keep double-entry
  bookkeeping focused on transfers while still providing higher-level investment
  analytics and traceability in Finance.
  """

  use Ecto.Migration

  def up do
    create table(:investments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :name, :text, null: false
      add :type, :text, null: false
      add :subtype, :text, null: false
      add :initial_value, :money_with_currency, null: false
      add :current_value, :money_with_currency, null: false
      add :redemption_date, :date
      add :purchase_date, :date

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :account_id,
          references(:ledger_accounts,
            column: :id,
            name: "investments_account_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false
    end

    create unique_index(:investments, [:name], name: "investments_unique_name_index")
    create index(:investments, [:account_id])
    create index(:investments, [:type])
    create index(:investments, [:subtype])

    create constraint(:investments, :investments_type_subtype_check,
             check: """
               (type = 'renda_fixa' AND subtype IN ('cdb', 'lci_lca', 'cri_cra', 'debentures')) OR
               (type = 'fundos' AND subtype IN ('renda_fixa', 'multimercado')) OR
               (type = 'tesouro_direto' AND subtype IN ('selic', 'prefixado', 'ipca')) OR
               (type = 'renda_variavel' AND subtype IN ('fiis', 'acoes'))
             """
           )

    create table(:investment_histories, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :value, :money_with_currency, null: false
      add :recorded_on, :date, null: false

      add :investment_id,
          references(:investments,
            column: :id,
            name: "investment_histories_investment_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:investment_histories, [:investment_id])
    create index(:investment_histories, [:recorded_on])

    create table(:investment_operations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :type, :text, null: false
      add :value, :money_with_currency, null: false

      add :investment_id,
          references(:investments,
            column: :id,
            name: "investment_operations_investment_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:investment_operations, [:investment_id])
    create index(:investment_operations, [:type])
  end

  def down do
    drop_if_exists index(:investment_operations, [:type])
    drop_if_exists index(:investment_operations, [:investment_id])

    drop constraint(:investment_operations, "investment_operations_investment_id_fkey")
    drop table(:investment_operations)

    drop_if_exists index(:investment_histories, [:recorded_on])
    drop_if_exists index(:investment_histories, [:investment_id])

    drop constraint(:investment_histories, "investment_histories_investment_id_fkey")
    drop table(:investment_histories)

    drop_if_exists constraint(:investments, :investments_type_subtype_check)
    drop_if_exists index(:investments, [:subtype])
    drop_if_exists index(:investments, [:type])
    drop_if_exists index(:investments, [:account_id])
    drop_if_exists unique_index(:investments, [:name], name: "investments_unique_name_index")

    drop constraint(:investments, "investments_account_id_fkey")
    drop table(:investments)
  end
end

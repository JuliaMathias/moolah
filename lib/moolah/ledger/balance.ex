defmodule Moolah.Ledger.Balance do
  @moduledoc """
  Represents account balance snapshots after each transfer.

  Balances act as a materialized view for account balances, providing
  efficient querying of account balances at specific points in time
  without needing to recalculate from all historical transfers.
  """
  use Ash.Resource,
    domain: Elixir.Moolah.Ledger,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshDoubleEntry.Balance]

  balance do
    transfer_resource Moolah.Ledger.Transfer
    account_resource Moolah.Ledger.Account
  end

  postgres do
    table "ledger_balances"
    repo Moolah.Repo
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false
    end

    create :upsert_balance do
      accept [:balance, :account_id, :transfer_id]
      upsert? true
      upsert_identity :unique_references
    end

    update :adjust_balance do
      argument :from_account_id, :uuid_v7, allow_nil?: false
      argument :to_account_id, :uuid_v7, allow_nil?: false
      argument :delta, :money, allow_nil?: false
      argument :transfer_id, AshDoubleEntry.ULID, allow_nil?: false

      change filter expr(
                      account_id in [^arg(:from_account_id), ^arg(:to_account_id)] and
                        transfer_id > ^arg(:transfer_id)
                    )

      change {AshDoubleEntry.Balance.Changes.AdjustBalance, can_add_money?: true}
    end
  end

  policies do
    # Allow read access for everyone
    policy action_type(:read) do
      authorize_if always()
    end

    # Allow destroy access (for internal cleanup)
    # We authorize it for everyone here because we don't have fine-grained actors yet,
    # but having the authorizer ensures it doesn't leak through public interfaces unintentionally.
    policy action(:destroy) do
      authorize_if always()
    end

    # Allow upsert and adjust balances (internal system maintenance)
    policy action([:upsert_balance, :adjust_balance]) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :balance, :money do
      constraints storage_type: :money_with_currency
    end
  end

  relationships do
    belongs_to :transfer, Moolah.Ledger.Transfer do
      attribute_type AshDoubleEntry.ULID
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :account, Moolah.Ledger.Account do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_references, [:account_id, :transfer_id]
  end
end

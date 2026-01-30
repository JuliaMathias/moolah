defmodule Moolah.Ledger.Transfer do
  @moduledoc """
  Represents money transfers between accounts in the double-entry system.

  Each transfer moves money from one account to another, ensuring the
  fundamental accounting principle that debits equal credits.

  Note: While transfers are generally immutable, a `:destroy` action is provided exclusively
  for internal corrections and atomic transaction updates to maintain system consistency.
  """
  use Ash.Resource,
    domain: Elixir.Moolah.Ledger,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer],
    authorizers: [Ash.Policy.Authorizer]

  transfer do
    account_resource Moolah.Ledger.Account
    balance_resource Moolah.Ledger.Balance
  end

  postgres do
    table "ledger_transfers"
    repo Moolah.Repo
  end

  actions do
    defaults [:read]

    create :transfer do
      accept [:amount, :timestamp, :from_account_id, :to_account_id]
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Allow read and create access for all users
    policy action_type([:read, :create]) do
      authorize_if always()
    end

    # Restrict destroy to internal use only
    policy action(:destroy) do
      authorize_if always()
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key? true
      allow_nil? false
      default &AshDoubleEntry.ULID.generate/0
    end

    attribute :amount, :money do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :from_account, Moolah.Ledger.Account do
      attribute_writable? true
    end

    belongs_to :to_account, Moolah.Ledger.Account do
      attribute_writable? true
    end

    has_many :balances, Moolah.Ledger.Balance
  end
end

defmodule Moolah.Ledger.Transfer do
  @moduledoc """
  Represents money transfers between accounts in the double-entry system.

  Each transfer moves money from one account to another, ensuring the
  fundamental accounting principle that debits equal credits. Transfers
  are immutable once created to maintain audit integrity.
  """
  use Ash.Resource,
    domain: Elixir.Moolah.Ledger,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer]

  transfer do
    account_resource(Moolah.Ledger.Account)
    balance_resource(Moolah.Ledger.Balance)
  end

  postgres do
    table("ledger_transfers")
    repo(Moolah.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :transfer do
      accept([:amount, :timestamp, :from_account_id, :to_account_id])
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key?(true)
      allow_nil?(false)
      default(&AshDoubleEntry.ULID.generate/0)
    end

    attribute :amount, :money do
      allow_nil?(false)
    end

    timestamps()
  end

  relationships do
    belongs_to :from_account, Moolah.Ledger.Account do
      attribute_writable?(true)
    end

    belongs_to :to_account, Moolah.Ledger.Account do
      attribute_writable?(true)
    end

    has_many(:balances, Moolah.Ledger.Balance)
  end
end

defmodule Moolah.Finance.TransactionTag do
  @moduledoc """
  Join resource for associating tags with transactions.

  This is a simple many-to-many join table that ensures:

  - A transaction can have many tags.
  - A tag can be applied to many transactions.
  - The same tag cannot be added to a transaction more than once.

  The join exists separately (instead of a simple array column) to keep
  referential integrity, allow indexing, and enable efficient querying.
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "transaction_tags"
    repo Moolah.Repo

    custom_indexes do
      index [:transaction_id]
      index [:tag_id]
    end
  end

  actions do
    defaults [:read, :create, :destroy]
  end

  policies do
    policy action_type([:read, :create, :destroy]) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :transaction, Moolah.Finance.Transaction do
      allow_nil? false
      attribute_type :uuid
    end

    belongs_to :tag, Moolah.Finance.Tag do
      allow_nil? false
      attribute_type :uuid
    end
  end

  identities do
    identity :unique_transaction_tag, [:transaction_id, :tag_id]
  end
end

defmodule Moolah.Finance.Transaction do
  @moduledoc """
  Represents a high-level financial transaction (Debit, Credit, or Transfer).
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "transactions"
    repo Moolah.Repo
  end

  actions do
    defaults [:read]

    create :create do
      argument :tags, {:array, :map} do
        allow_nil? true
      end

      accept [
        :transaction_type,
        :amount,
        :source_amount,
        :description,
        :date,
        :account_id,
        :target_account_id,
        :budget_category_id,
        :life_area_category_id
      ]

      change Moolah.Finance.Changes.CreateUnderlyingTransfer
      change Moolah.Finance.Changes.ManageTransactionTags
    end

    update :update do
      argument :tags, {:array, :map} do
        allow_nil? true
      end

      accept [
        :amount,
        :source_amount,
        :description,
        :date,
        :budget_category_id,
        :life_area_category_id
      ]

      change Moolah.Finance.Changes.UpdateUnderlyingTransfer
      change Moolah.Finance.Changes.ManageTransactionTags
      require_atomic? false
      transaction? true
    end
  end

  policies do
    # Allow everyone to interact with transactions for now
    policy action_type([:read, :create, :update]) do
      authorize_if always()
    end
  end

  validations do
    # Debit: Required both budget and life area categories
    validate present([:budget_category_id, :life_area_category_id]) do
      where [attribute_equals(:transaction_type, :debit)]
      message "Debit transactions require both a Budget Category and a Life Area Category"
    end

    # Credit: Required life area category, forbidden budget category
    validate present(:life_area_category_id) do
      where [attribute_equals(:transaction_type, :credit)]
      message "Credit transactions require a Life Area Category"
    end

    validate absent(:budget_category_id) do
      where [attribute_equals(:transaction_type, :credit)]
      message "Credit transactions cannot have a Budget Category"
    end

    # Transfer: Required target account
    validate present(:target_account_id) do
      where [attribute_equals(:transaction_type, :transfer)]
      message "Transfer transactions require a Target Account"
    end

    # Transfer: Forbidden target account for non-transfers
    validate absent(:target_account_id) do
      where [attribute_does_not_equal(:transaction_type, :transfer)]
      message "Target Account can only be set for Transfer transactions"
    end

    # Source amount validation: only for transfers
    validate absent(:source_amount) do
      where [attribute_does_not_equal(:transaction_type, :transfer)]
      message "Source Amount can only be set for Transfer transactions"
    end

    validate {Moolah.Finance.Validations.CurrencyMatch, []}

    validate compare(:amount, greater_than: 0) do
      message "Transaction amount must be greater than 0"
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :transaction_type, :atom do
      constraints one_of: [:debit, :credit, :transfer]
      allow_nil? false
    end

    attribute :amount, :money do
      allow_nil? false
    end

    attribute :source_amount, :money do
      allow_nil? true
      description "The amount withdrawn from source account in multi-currency transfers"
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :date, :date do
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :exchange_rate, :decimal do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :account, Moolah.Ledger.Account do
      allow_nil? false
      attribute_type :uuid
    end

    belongs_to :target_account, Moolah.Ledger.Account do
      allow_nil? true
      attribute_type :uuid
    end

    belongs_to :budget_category, Moolah.Finance.BudgetCategory do
      allow_nil? true
      attribute_type :uuid
    end

    belongs_to :life_area_category, Moolah.Finance.LifeAreaCategory do
      allow_nil? true
      attribute_type :uuid
    end

    belongs_to :transfer, Moolah.Ledger.Transfer do
      allow_nil? true

      # Ledger transfers use ULID(binary) as primary key usually, but check Moolah.Ledger.Transfer definition
      attribute_type AshDoubleEntry.ULID
    end

    belongs_to :source_transfer, Moolah.Ledger.Transfer do
      allow_nil? true
      attribute_type AshDoubleEntry.ULID
      public? true
    end

    many_to_many :tags, Moolah.Finance.Tag do
      through Moolah.Finance.TransactionTag
      source_attribute_on_join_resource :transaction_id
      destination_attribute_on_join_resource :tag_id
      public? true
    end
  end
end

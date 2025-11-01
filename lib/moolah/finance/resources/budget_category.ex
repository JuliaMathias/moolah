defmodule Moolah.Finance.BudgetCategory do
  @moduledoc """
  Budget categories for categorizing expenses based on the AUVP financial education methodology.

  Budget categories are fixed, system-defined categories used to classify debit transactions
  and optionally transfer transactions. These categories help users understand their spending
  patterns according to established financial planning principles.

  ## Categories

  The system includes six predefined categories:
  - Fixed Costs: Monthly recurring expenses (rent, utilities, insurance)
  - Comfort: Non-essential quality-of-life improvements
  - Goals: Planned purchases and savings objectives
  - Pleasures: Entertainment and social spending
  - Financial Liberty: Long-term investments and wealth building
  - Knowledge: Education and personal development

  ## Usage Rules

  - **Debit transactions**: Required (must have both budget + life area category)
  - **Transfer transactions**: Optional (can have budget category)
  - **Credit transactions**: Not applicable (credit uses life area categories only)

  ## Restrictions

  Budget categories are seeded during database setup and cannot be created or deleted
  via standard actions. Only read and update operations are permitted.
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "budget_categories"
    repo Moolah.Repo
  end

  # Only define read and update actions - omitting create/destroy
  actions do
    defaults [:read]

    update :update do
      accept [:name, :description, :icon, :color]
      require_atomic? false
    end
  end

  # Policies: Allow read/update, explicitly forbid create/destroy
  policies do
    # Allow anyone to read budget categories
    policy action_type(:read) do
      authorize_if always()
    end

    # Allow updates (for system maintenance)
    policy action_type(:update) do
      authorize_if always()
    end

    # Explicitly forbid creation and deletion
    policy action_type([:create, :destroy]) do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :icon, :string do
      allow_nil? false
      public? true
    end

    attribute :color, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_name, [:name]
  end
end

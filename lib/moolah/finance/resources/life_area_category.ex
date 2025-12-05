defmodule Moolah.Finance.LifeAreaCategory do
  @moduledoc """
  Life area categories for classifying transactions in a hierarchical structure.

  Supports a 2-level hierarchy:
  - **Root categories** (depth 0): Top-level life areas (e.g., Health, Education, Food)
  - **Child categories** (depth 1): Specific subcategories (e.g., Medical, Fitness under Health)

  ## Transaction Type Usage

  Categories are tagged with transaction_type to indicate where they can be used:
  - **:debit** - For expense transactions (money leaving your accounts)
  - **:credit** - For income transactions (money entering your accounts)
  - **:both** - Can be used for either type (e.g., Reimbursements)

  ## Hierarchy Rules

  - Maximum depth: 2 levels (root → child only, no grandchildren)
  - No circular references (category cannot be its own ancestor)
  - Parents cannot be deleted if they have children
  - Same name allowed under different parents or as different roots

  ## Examples

      # Root category
      %LifeAreaCategory{
        name: "Health",
        parent_id: nil,
        depth: 0,
        transaction_type: :debit
      }

      # Child category
      %LifeAreaCategory{
        name: "Medical",
        parent_id: <health_category_id>,
        depth: 1,
        transaction_type: :debit
      }
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "life_area_categories"
    repo Moolah.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :description, :icon, :color, :transaction_type, :parent_id, :depth]
    end

    update :update do
      accept [:name, :description, :icon, :color, :transaction_type, :parent_id, :depth]
      require_atomic? false
    end

    destroy :destroy do
      require_atomic? false
    end

    # Helper action to get only root categories (no parent)
    read :roots do
      filter expr(is_nil(parent_id))
    end

    # Helper action to preload children
    read :with_children do
      prepare fn query, _ ->
        Ash.Query.load(query, :children)
      end
    end
  end

  policies do
    # Allow anyone to read categories
    policy action_type(:read) do
      authorize_if always()
    end

    # Allow create and update operations
    policy action_type([:create, :update]) do
      authorize_if always()
    end

    # Allow destroy (validation will prevent if has children)
    policy action_type(:destroy) do
      authorize_if always()
    end
  end

  validations do
    # Prevent circular references in the hierarchy
    validate {Moolah.Finance.Validations.NoCycleReference, []} do
      on [:create, :update]
    end

    # Enforce maximum depth of 2 levels
    validate {Moolah.Finance.Validations.MaxDepth, max_depth: 2} do
      on [:create, :update]
    end

    # Prevent deletion of categories with children
    validate {Moolah.Finance.Validations.NoChildrenOnDelete, []} do
      on [:destroy]
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

    attribute :transaction_type, :atom do
      constraints one_of: [:debit, :credit, :both]
      allow_nil? false
      public? true
    end

    attribute :depth, :integer do
      allow_nil? false
      default 0
      public? true
    end

    timestamps()
  end

  relationships do
    # Self-referencing relationship for parent
    belongs_to :parent, __MODULE__ do
      allow_nil? true
      public? true
    end

    # Has many children pointing back to this category
    has_many :children, __MODULE__ do
      destination_attribute :parent_id
      public? true
    end
  end

  identities do
    # Allow same name under different parents
    # PostgreSQL treats NULL as distinct, so multiple roots can have same name
    identity :unique_name_per_parent, [:name, :parent_id] do
      eager_check_with Moolah.Repo
    end
  end
end

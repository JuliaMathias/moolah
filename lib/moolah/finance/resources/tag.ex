defmodule Moolah.Finance.Tag do
  @moduledoc """
  User-defined tags for labeling transactions.

  Tags are optional metadata that help users organize transactions without being
  constrained to fixed system categories. Each tag has a display name, a URL-friendly
  slug for stable references, and a color used by the UI.

  ## Key behaviors

  - **Case-insensitive uniqueness** on `name` (stored as `:ci_string`), while preserving
    the original casing for display.
  - **Slug normalization** from the name on create/update.
  - **Soft deletion** via `archived_at` so historical transactions retain their tags.

  ## Actions

  - `:create` and `:update` normalize the name and slug.
  - `:find_or_create` upserts by case-insensitive name for on-demand creation during
    transaction entry.
  - `:destroy` is soft, setting `archived_at`.
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  postgres do
    table "tags"
    repo Moolah.Repo

    check_constraints do
      check_constraint :color, "tags_color_hex_check",
        check: "color ~* '^#[0-9A-F]{6}$'",
        message: "must be a valid hex color"
    end
  end

  actions do
    read :read do
      primary? true
      filter expr(is_nil(archived_at))
    end

    read :including_archived

    create :create do
      accept [:name, :color, :description]
      change {Moolah.Finance.Changes.NormalizeTagName, field: :name}
      change {Moolah.Finance.Changes.GenerateTagSlug, source: :name, target: :slug}
    end

    create :find_or_create do
      accept [:name, :color, :description]
      upsert? true
      upsert_identity :unique_name
      upsert_fields [:name, :slug]
      change {Moolah.Finance.Changes.NormalizeTagName, field: :name}
      change {Moolah.Finance.Changes.GenerateTagSlug, source: :name, target: :slug}
    end

    update :update do
      accept [:name, :color, :description]
      require_atomic? false
      change {Moolah.Finance.Changes.NormalizeTagName, field: :name}
      change {Moolah.Finance.Changes.GenerateTagSlug, source: :name, target: :slug}
    end

    destroy :destroy do
      soft? true
      require_atomic? false
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :ci_string do
      allow_nil? false
      public? true
      constraints max_length: 100, min_length: 1
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints max_length: 100, min_length: 1
    end

    attribute :color, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^#[0-9A-F]{6}$/i
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 500
    end

    attribute :archived_at, :utc_datetime_usec do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    many_to_many :transactions, Moolah.Finance.Transaction do
      through Moolah.Finance.TransactionTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :transaction_id
    end
  end

  identities do
    identity :unique_name, [:name]
    identity :unique_slug, [:slug]
  end
end

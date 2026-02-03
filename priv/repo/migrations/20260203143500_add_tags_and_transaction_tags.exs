defmodule Moolah.Repo.Migrations.AddTagsAndTransactionTags do
  @moduledoc """
  Adds tag support for transactions (Issue #15).

  This consolidated migration creates the `tags` table (with slug, color, and soft-delete fields)
  and the `transaction_tags` join table to associate tags with transactions. It also enforces the
  uniqueness and validation constraints needed for tag integrity and query performance.
  """

  use Ecto.Migration

  def up do
    create table(:tags, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :name, :citext, null: false
      add :slug, :text, null: false
      add :color, :text, null: false
      add :description, :text
      add :archived_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:tags, [:name], name: "tags_unique_name_index")
    create unique_index(:tags, [:slug], name: "tags_unique_slug_index")

    create constraint(:tags, :tags_color_hex_check,
             check: """
               color ~* '^#[0-9A-F]{6}$'
             """
           )

    create table(:transaction_tags, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true

      add :transaction_id,
          references(:transactions,
            column: :id,
            name: "transaction_tags_transaction_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :tag_id,
          references(:tags,
            column: :id,
            name: "transaction_tags_tag_id_fkey",
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

    create unique_index(:transaction_tags, [:transaction_id, :tag_id],
             name: "transaction_tags_unique_transaction_tag_index"
           )

    create index(:transaction_tags, [:transaction_id])
    create index(:transaction_tags, [:tag_id])
  end

  def down do
    drop_if_exists index(:transaction_tags, [:tag_id])
    drop_if_exists index(:transaction_tags, [:transaction_id])

    drop_if_exists unique_index(:transaction_tags, [:transaction_id, :tag_id],
                     name: "transaction_tags_unique_transaction_tag_index"
                   )

    drop constraint(:transaction_tags, "transaction_tags_tag_id_fkey")
    drop constraint(:transaction_tags, "transaction_tags_transaction_id_fkey")
    drop table(:transaction_tags)

    drop_if_exists constraint(:tags, :tags_color_hex_check)
    drop_if_exists unique_index(:tags, [:slug], name: "tags_unique_slug_index")
    drop_if_exists unique_index(:tags, [:name], name: "tags_unique_name_index")
    drop table(:tags)
  end
end

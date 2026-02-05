defmodule Moolah.Repo.Migrations.AddUserNames do
  @moduledoc """
  Stores user first and last names for profile and onboarding flows.

  We capture names during registration so the product can address users
  personally and future onboarding steps can pre-fill profiles. The columns
  are nullable to avoid breaking existing accounts while new registrations
  require both values.
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      add :first_name, :text
      add :last_name, :text
    end
  end

  def down do
    alter table(:users) do
      remove :last_name
      remove :first_name
    end
  end
end

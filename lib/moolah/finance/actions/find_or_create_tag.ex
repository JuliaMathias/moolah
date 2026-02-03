defmodule Moolah.Finance.Actions.FindOrCreateTag do
  @moduledoc """
  Manual create action for tags that ignores archived records.

  If an active tag exists with the given name, it is returned. If only an archived
  tag exists, creation is attempted and fails due to the unique name constraint.
  """

  use Ash.Resource.ManualCreate

  alias Ash.Resource.ManualCreate.Context
  alias Moolah.Finance.Tag

  require Ash.Query

  @spec create(Ash.Changeset.t(), Keyword.t(), Context.t()) ::
          {:ok, Ash.Resource.record()}
          | {:ok, Ash.Resource.record(), %{notifications: [Ash.Notifier.Notification.t()]}}
          | {:error, term()}
  def create(changeset, _opts, %Context{} = context) do
    name = Ash.Changeset.get_attribute(changeset, :name)

    existing =
      Tag
      |> Ash.Query.filter(name == ^name)
      |> Ash.read_one(
        action: :read,
        domain: context.domain,
        actor: context.actor,
        tenant: context.tenant,
        authorize?: context.authorize?
      )

    case existing do
      {:ok, %Tag{} = tag} ->
        {:ok, tag}

      {:ok, nil} ->
        attrs = %{
          name: name,
          color: Ash.Changeset.get_attribute(changeset, :color),
          description: Ash.Changeset.get_attribute(changeset, :description)
        }

        Tag
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.create(
          domain: context.domain,
          actor: context.actor,
          tenant: context.tenant,
          authorize?: context.authorize?
        )

      {:error, error} ->
        {:error, error}
    end
  end
end

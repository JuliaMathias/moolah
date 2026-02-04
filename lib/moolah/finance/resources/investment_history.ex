defmodule Moolah.Finance.InvestmentHistory do
  @moduledoc """
  Represents a dated snapshot of an investment's value.

  These records are created by `Moolah.Finance.Changes.CreateInvestmentHistory` to
  build a time series for an investment.

  ## Examples

      iex> Moolah.Finance.InvestmentHistory
      ...> |> Ash.Changeset.for_create(:create, %{
      ...>   investment_id: investment.id,
      ...>   recorded_on: Date.utc_today(),
      ...>   value: Money.new(1250, :BRL)
      ...> })
      ...> |> Ash.create()
      {:ok, %Moolah.Finance.InvestmentHistory{}}
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Moolah.Finance.Investment

  postgres do
    table "investment_histories"
    repo Moolah.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:value, :recorded_on, :investment_id]
    end

    destroy :destroy do
      primary? true
      require_atomic? false
    end
  end

  policies do
    policy action_type([:read, :create, :destroy]) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :value, :money do
      allow_nil? false
      constraints storage_type: :money_with_currency
    end

    attribute :recorded_on, :date do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :investment, Investment do
      allow_nil? false
      attribute_type :uuid
    end
  end
end

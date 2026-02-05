defmodule Moolah.Finance.InvestmentOperation do
  @moduledoc """
  Represents a tracked operation performed on an investment's value.

  Operations are created automatically when the investment value changes.

  ## Examples

      iex> Moolah.Finance.InvestmentOperation
      ...> |> Ash.Changeset.for_create(:create, %{
      ...>   investment_id: investment.id,
      ...>   type: :update,
      ...>   value: Money.new(50, :BRL)
      ...> })
      ...> |> Ash.create()
      {:ok, %Moolah.Finance.InvestmentOperation{}}
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Moolah.Finance.Investment
  alias Moolah.Finance.Transaction
  alias Moolah.Finance.Validations.ValidateOperationCurrency

  postgres do
    table "investment_operations"
    repo Moolah.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:type, :value, :investment_id, :transaction_id]
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

  validations do
    validate {ValidateOperationCurrency, []}
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [:deposit, :withdraw, :update]
    end

    attribute :value, :money do
      allow_nil? false
      constraints storage_type: :money_with_currency
    end

    timestamps()
  end

  relationships do
    belongs_to :investment, Investment do
      allow_nil? false
      attribute_type :uuid
    end

    belongs_to :transaction, Transaction do
      allow_nil? true
      attribute_type :uuid
    end
  end
end

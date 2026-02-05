defmodule Moolah.Finance.Investment do
  @moduledoc """
  Represents an investment tied to a ledger investment account.

  The resource supports Brazilian investment types/subtypes, currency validation
  against the linked ledger account, and active/expired read filtering via
  `redemption_date`.

  ## Examples

      iex> Moolah.Finance.Investment
      ...> |> Ash.Changeset.for_create(:create, %{
      ...>   name: "Tesouro Selic",
      ...>   type: :tesouro_direto,
      ...>   subtype: :selic,
      ...>   initial_value: Money.new(1000, :BRL),
      ...>   current_value: Money.new(1100, :BRL),
      ...>   purchase_date: ~D[2025-01-10],
      ...>   redemption_date: ~D[2026-01-10],
      ...>   account_id: account.id
      ...> })
      ...> |> Ash.create()
      {:ok, %Moolah.Finance.Investment{}}
  """

  use Ash.Resource,
    domain: Moolah.Finance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  alias Moolah.Finance.Changes.CreateInvestmentHistory
  alias Moolah.Finance.Changes.TrackInvestmentOperation
  alias Moolah.Finance.Validations.ValidateInvestmentAccountType
  alias Moolah.Finance.Validations.ValidateInvestmentCurrency
  alias Moolah.Finance.Validations.ValidateInvestmentPurchaseDate
  alias Moolah.Finance.Validations.ValidateInvestmentSubtype
  alias Moolah.Ledger.Account

  @types [:renda_fixa, :fundos, :tesouro_direto, :renda_variavel]
  @renda_fixa_subtypes [:cdb, :lci_lca, :cri_cra, :debentures]
  @fundos_subtypes [:renda_fixa, :multimercado]
  @tesouro_direto_subtypes [:selic, :prefixado, :ipca]
  @renda_variavel_subtypes [:fiis, :acoes]
  @all_subtypes @renda_fixa_subtypes ++
                  @fundos_subtypes ++ @tesouro_direto_subtypes ++ @renda_variavel_subtypes

  postgres do
    table "investments"
    repo Moolah.Repo
  end

  actions do
    read :read do
      primary? true
      filter expr(is_nil(redemption_date) or redemption_date >= ^Date.utc_today())
    end

    read :including_expired

    create :create do
      accept [
        :name,
        :type,
        :subtype,
        :initial_value,
        :current_value,
        :redemption_date,
        :purchase_date,
        :account_id
      ]

      change {CreateInvestmentHistory, mode: :create}
    end

    update :update do
      accept [:name, :current_value, :redemption_date, :purchase_date]
      require_atomic? false

      change {CreateInvestmentHistory, mode: :update}
      change TrackInvestmentOperation
    end

    update :market_update do
      accept [:current_value, :redemption_date, :purchase_date]
      require_atomic? false

      change {CreateInvestmentHistory, mode: :update}
      change {TrackInvestmentOperation, mode: :market_update}
    end

    destroy :destroy do
      primary? true
      require_atomic? false
    end
  end

  policies do
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if always()
    end
  end

  validations do
    validate {ValidateInvestmentSubtype, []}
    validate {ValidateInvestmentCurrency, []}
    validate {ValidateInvestmentAccountType, []}
    validate {ValidateInvestmentPurchaseDate, []}
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 255, min_length: 1
    end

    attribute :type, :atom do
      allow_nil? false
      constraints one_of: @types
    end

    attribute :subtype, :atom do
      allow_nil? false
      constraints one_of: @all_subtypes
    end

    attribute :initial_value, :money do
      allow_nil? false
      constraints storage_type: :money_with_currency
    end

    attribute :current_value, :money do
      allow_nil? false
      constraints storage_type: :money_with_currency
    end

    attribute :redemption_date, :date do
      allow_nil? true
    end

    attribute :purchase_date, :date do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :account, Account do
      allow_nil? false
      attribute_type :uuid
    end

    has_many :histories, Moolah.Finance.InvestmentHistory do
      destination_attribute :investment_id
    end

    has_many :operations, Moolah.Finance.InvestmentOperation do
      destination_attribute :investment_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end

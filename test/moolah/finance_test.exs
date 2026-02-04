defmodule Moolah.FinanceTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Ash.Domain.Info
  alias Moolah.Finance
  alias Moolah.Finance.BudgetCategory
  alias Moolah.Finance.Investment
  alias Moolah.Finance.InvestmentHistory
  alias Moolah.Finance.InvestmentOperation
  alias Moolah.Finance.LifeAreaCategory
  alias Moolah.Finance.Tag
  alias Moolah.Finance.Transaction
  alias Moolah.Finance.TransactionTag

  describe "domain configuration" do
    test "domain is properly configured" do
      # Verify it's a valid Ash domain
      resources = Info.resources(Finance)
      assert is_list(resources)
      assert resources != []
    end

    test "domain includes all expected resources" do
      resources = Info.resources(Finance)

      expected_resources = [
        BudgetCategory,
        LifeAreaCategory,
        Tag,
        TransactionTag,
        Transaction,
        Investment,
        InvestmentHistory,
        InvestmentOperation
      ]

      for resource <- expected_resources do
        assert resource in resources,
               "Expected #{inspect(resource)} to be in Finance domain resources"
      end
    end
  end
end

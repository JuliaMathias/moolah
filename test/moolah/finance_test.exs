defmodule Moolah.FinanceTest do
  @moduledoc """
  Tests for the Moolah.Finance domain.
  """
  use Moolah.DataCase, async: true

  alias Moolah.Finance

  describe "domain configuration" do
    test "domain is properly configured" do
      # Verify it's a valid Ash domain
      resources = Ash.Domain.Info.resources(Finance)
      assert is_list(resources)
      assert resources != []
    end

    test "domain includes all expected resources" do
      resources = Ash.Domain.Info.resources(Finance)

      expected_resources = [
        Moolah.Finance.BudgetCategory,
        Moolah.Finance.LifeAreaCategory,
        Moolah.Finance.Tag,
        Moolah.Finance.TransactionTag,
        Moolah.Finance.Transaction,
        Moolah.Finance.Investment,
        Moolah.Finance.InvestmentHistory,
        Moolah.Finance.InvestmentOperation
      ]

      for resource <- expected_resources do
        assert resource in resources,
               "Expected #{inspect(resource)} to be in Finance domain resources"
      end
    end
  end
end

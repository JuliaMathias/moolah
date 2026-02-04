defmodule Moolah.LedgerTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Ledger

  describe "domain configuration" do
    test "domain is properly configured" do
      # Verify it's a valid Ash domain
      resources = Ash.Domain.Info.resources(Ledger)
      assert is_list(resources)
      assert resources != []
    end

    test "domain includes all expected resources" do
      resources = Ash.Domain.Info.resources(Ledger)

      expected_resources = [
        Moolah.Ledger.Account,
        Moolah.Ledger.Balance,
        Moolah.Ledger.Transfer
      ]

      for resource <- expected_resources do
        assert resource in resources,
               "Expected #{inspect(resource)} to be in Ledger domain resources"
      end
    end
  end
end

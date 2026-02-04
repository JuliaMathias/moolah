defmodule Moolah.LedgerTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Ash.Domain.Info
  alias Moolah.Ledger
  alias Moolah.Ledger.Account
  alias Moolah.Ledger.Balance
  alias Moolah.Ledger.Transfer

  describe "domain configuration" do
    test "domain is properly configured" do
      # Verify it's a valid Ash domain
      resources = Info.resources(Ledger)
      assert is_list(resources)
      assert resources != []
    end

    test "domain includes all expected resources" do
      resources = Info.resources(Ledger)

      expected_resources = [
        Account,
        Balance,
        Transfer
      ]

      for resource <- expected_resources do
        assert resource in resources,
               "Expected #{inspect(resource)} to be in Ledger domain resources"
      end
    end
  end
end

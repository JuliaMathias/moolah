defmodule Moolah.AccountsTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Ash.Domain.Info
  alias AshAdmin.Domain, as: AshAdminDomain
  alias Moolah.Accounts
  alias Moolah.Accounts.Token
  alias Moolah.Accounts.User

  describe "domain configuration" do
    test "domain is properly configured" do
      # Verify it's a valid Ash domain
      resources = Info.resources(Accounts)
      assert is_list(resources)
      assert resources != []
    end

    test "domain includes User resource" do
      resources = Info.resources(Accounts)
      assert User in resources
    end

    test "domain includes Token resource" do
      resources = Info.resources(Accounts)
      assert Token in resources
    end

    test "domain has admin interface enabled" do
      # Check if AshAdmin extension is present
      extensions = Info.extensions(Accounts)
      assert AshAdminDomain in extensions
    end
  end
end

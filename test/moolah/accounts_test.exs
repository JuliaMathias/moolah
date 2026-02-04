defmodule Moolah.AccountsTest do
  @moduledoc false
  use Moolah.DataCase, async: true

  alias Moolah.Accounts

  describe "domain configuration" do
    test "domain is properly configured" do
      # Verify it's a valid Ash domain
      resources = Ash.Domain.Info.resources(Accounts)
      assert is_list(resources)
      assert resources != []
    end

    test "domain includes User resource" do
      resources = Ash.Domain.Info.resources(Accounts)
      assert Moolah.Accounts.User in resources
    end

    test "domain includes Token resource" do
      resources = Ash.Domain.Info.resources(Accounts)
      assert Moolah.Accounts.Token in resources
    end

    test "domain has admin interface enabled" do
      # Check if AshAdmin extension is present
      extensions = Ash.Domain.Info.extensions(Accounts)
      assert AshAdmin.Domain in extensions
    end
  end
end

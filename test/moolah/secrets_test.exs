defmodule Moolah.SecretsTest do
  @moduledoc """
  Tests for the Moolah.Secrets module.
  """
  use Moolah.DataCase, async: true

  alias Moolah.Accounts.User
  alias Moolah.Secrets

  describe "secret_for/4" do
    test "retrieves token signing secret from application configuration" do
      # The token signing secret should be configured in the test environment
      assert {:ok, secret} =
               Secrets.secret_for(
                 [:authentication, :tokens, :signing_secret],
                 User,
                 [],
                 %{}
               )

      assert is_binary(secret)
      assert byte_size(secret) > 0
    end

    test "returns error when secret is not configured" do
      # Temporarily clear the config
      original_value = Application.get_env(:moolah, :token_signing_secret)
      Application.delete_env(:moolah, :token_signing_secret)

      assert :error =
               Secrets.secret_for(
                 [:authentication, :tokens, :signing_secret],
                 User,
                 [],
                 %{}
               )

      # Restore the original value
      if original_value do
        Application.put_env(:moolah, :token_signing_secret, original_value)
      end
    end
  end
end

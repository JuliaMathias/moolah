defmodule Moolah.SecretsTest do
  @moduledoc false
  use Moolah.DataCase, async: false

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
      # Capture the original configuration state
      original = Application.fetch_env(:moolah, :token_signing_secret)

      # Ensure cleanup happens even if test fails
      on_exit(fn ->
        case original do
          {:ok, value} -> Application.put_env(:moolah, :token_signing_secret, value)
          :error -> Application.delete_env(:moolah, :token_signing_secret)
        end
      end)

      # Temporarily clear the config
      Application.delete_env(:moolah, :token_signing_secret)

      assert :error =
               Secrets.secret_for(
                 [:authentication, :tokens, :signing_secret],
                 User,
                 [],
                 %{}
               )
    end
  end
end

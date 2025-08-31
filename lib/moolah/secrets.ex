defmodule Moolah.Secrets do
  @moduledoc """
  Provides secret management for AshAuthentication.

  Handles secure retrieval of authentication secrets like
  token signing keys from application configuration.
  """
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Moolah.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:moolah, :token_signing_secret)
  end
end

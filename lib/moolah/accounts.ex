defmodule Moolah.Accounts do
  @moduledoc """
  The Accounts domain handles user authentication and management.

  This domain manages users and authentication tokens using AshAuthentication
  with support for password-based and magic link authentication.
  """
  use Ash.Domain, otp_app: :moolah, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Moolah.Accounts.Token
    resource Moolah.Accounts.User
  end
end

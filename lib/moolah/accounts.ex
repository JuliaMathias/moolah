defmodule Moolah.Accounts do
  use Ash.Domain, otp_app: :moolah, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Moolah.Accounts.Token
    resource Moolah.Accounts.User
  end
end

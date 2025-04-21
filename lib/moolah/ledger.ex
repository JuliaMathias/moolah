defmodule Moolah.Ledger do
  use Ash.Domain,
    otp_app: :moolah

  resources do
    resource Moolah.Ledger.Account
    resource Moolah.Ledger.Balance
    resource Moolah.Ledger.Transfer
  end
end

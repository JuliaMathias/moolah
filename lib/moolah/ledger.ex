defmodule Moolah.Ledger do
  @moduledoc """
  The Ledger domain handles double-entry bookkeeping functionality.

  This domain manages accounts, transfers, and balances using the AshDoubleEntry
  extension to ensure financial data integrity.
  """
  use Ash.Domain,
    otp_app: :moolah

  resources do
    resource Moolah.Ledger.Account
    resource Moolah.Ledger.Balance
    resource Moolah.Ledger.Transfer
  end
end

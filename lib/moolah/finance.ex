defmodule Moolah.Finance do
  @moduledoc """
  The Finance domain handles budget-related resources and financial planning.

  This domain manages budget categories and related financial planning features,
  separate from the core Ledger domain which handles double-entry bookkeeping.
  """

  use Ash.Domain, otp_app: :moolah

  resources do
    resource(Moolah.Finance.BudgetCategory)
    resource(Moolah.Finance.LifeAreaCategory)
    resource(Moolah.Finance.Transaction)
  end
end

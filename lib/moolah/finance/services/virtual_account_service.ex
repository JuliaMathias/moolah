defmodule Moolah.Finance.Services.VirtualAccountService do
  @moduledoc """
  Manages creation and retrieval of virtual accounts for double-entry bookkeeping.
  """

  require Ash.Query

  @doc """
  Gets or creates a virtual account for a category.

  ## key_prefix
  - :expense -> "expense"
  - :income -> "income"
  """

  @spec get_or_create(Ecto.UUID.t(), :expense | :income, String.t()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  def get_or_create(category_id, key_prefix, currency \\ "BRL") do
    # Construct a stable identifier using prefix, currency, and the category UUID
    identifier = "#{key_prefix}:#{currency}:#{category_id}"
    account_type = if key_prefix == :expense, do: :expense_category, else: :income_category

    Moolah.Ledger.Account
    |> Ash.Changeset.for_create(:open, %{
      identifier: identifier,
      currency: currency,
      account_type: account_type
    })
    |> Ash.Changeset.set_context(%{
      private: %{upsert?: true, upsert_identity: :unique_identifier}
    })
    |> Ash.create()
  end

  @doc """
  Gets or creates a trading account for a currency.

  Trading accounts are used in double-entry bookkeeping to handle currency
  conversions and multi-currency transactions. Each currency has its own
  trading account with a unique identifier.

  ## Parameters
  - `currency` - The currency code (e.g., "BRL", "USD", "EUR")

  ## Returns
  Returns the `Moolah.Ledger.Account` struct for the trading account.
  Raises an error if the database operation fails.

  ## Examples

      iex> get_or_create_trading_account!("BRL")
      %Moolah.Ledger.Account{identifier: "trading:BRL", account_type: :trading_account, ...}

      iex> get_or_create_trading_account!("USD")
      %Moolah.Ledger.Account{identifier: "trading:USD", account_type: :trading_account, ...}

  ## Notes
  - The account identifier follows the format: `"trading:\#{currency}"`
  - This function uses bang (!) versions and will raise on errors
  - If the account already exists, it returns the existing account
  """
  @spec get_or_create_trading_account!(String.t()) :: Ash.Resource.record()
  def get_or_create_trading_account!(currency) do
    identifier = "trading:#{currency}"

    Moolah.Ledger.Account
    |> Ash.Changeset.for_create(:open, %{
      identifier: identifier,
      currency: currency,
      account_type: :trading_account
    })
    |> Ash.Changeset.set_context(%{
      private: %{upsert?: true, upsert_identity: :unique_identifier}
    })
    |> Ash.create!()
  end
end

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
    # Construct a stable identifier using the UUID
    identifier = "#{key_prefix}:#{category_id}"
    account_type = if key_prefix == :expense, do: :expense_category, else: :income_category

    Moolah.Ledger.Account
    |> Ash.Query.filter(identifier == ^identifier)
    |> Ash.read_one()
    |> case do
      {:ok, account} when not is_nil(account) ->
        {:ok, account}

      {:ok, nil} ->
        Moolah.Ledger.Account
        |> Ash.Changeset.for_create(:open, %{
          identifier: identifier,
          currency: currency,
          account_type: account_type
        })
        |> Ash.create()

      error ->
        error
    end
  end
end

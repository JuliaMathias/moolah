defmodule Moolah.Finance.Validations.ValidateInvestmentPurchaseDate do
  @moduledoc """
  Validates that the investment purchase date is not in the future.

  This prevents time-series history snapshots from being recorded on a future
  date, which can skew reporting and charts.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.Investment
      ...>   |> Ash.Changeset.for_create(:create, %{
      ...>     purchase_date: Date.add(Date.utc_today(), -1)
      ...>   })
      iex> Moolah.Finance.Validations.ValidateInvestmentPurchaseDate.validate(
      ...>   changeset,
      ...>   [],
      ...>   %{}
      ...> )
      :ok
  """

  use Ash.Resource.Validation

  alias Ash.Changeset

  @impl true
  @doc """
  Ensures `purchase_date` is today or earlier when provided.

  Returns `:ok` when the purchase date is nil or not in the future.
  Returns an error when the purchase date is after today.
  """
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    purchase_date =
      Changeset.get_attribute(changeset, :purchase_date) || changeset.data.purchase_date

    case purchase_date do
      nil ->
        :ok

      date when Date.compare(date, Date.utc_today()) in [:lt, :eq] ->
        :ok

      _ ->
        {:error, field: :purchase_date, message: "must not be in the future"}
    end
  end
end

defmodule Moolah.Finance.Changes.CreateInvestmentHistory do
  @moduledoc """
  Creates investment history snapshots when investments are created or updated.

  This change is used by the Investment resource to persist time-series snapshots
  for reporting and performance tracking.

  This module intentionally allows multiple snapshots per day for the same
  investment, so intraday value changes (e.g., stocks) can be captured.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.Investment
      ...>   |> Ash.Changeset.for_create(:create, %{
      ...>     name: "Sample",
      ...>     type: :renda_fixa,
      ...>     subtype: :cdb,
      ...>     initial_value: Money.new(100, :BRL),
      ...>     current_value: Money.new(100, :BRL),
      ...>     account_id: account.id
      ...>   })
      iex> changeset =
      ...>   Moolah.Finance.Changes.CreateInvestmentHistory.change(changeset, [mode: :create], %{})
      iex> match?(%Ash.Changeset{}, changeset)
      true
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Moolah.Finance.InvestmentHistory

  @impl true
  @spec change(Changeset.t(), keyword(), map()) :: Changeset.t()
  def change(changeset, opts, _context) do
    mode = Keyword.get(opts, :mode, :create)

    Changeset.after_action(changeset, fn _changeset, record ->
      case mode do
        :create -> create_history_on_create(record)
        :update -> create_history_on_update(changeset, record)
        _ -> {:ok, record}
      end
    end)
  end

  @spec create_history_on_create(Ash.Resource.record()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_history_on_create(record) do
    # Build history snapshots based on purchase date and current value.
    today = Date.utc_today()
    purchase_date = record.purchase_date
    initial_value = record.initial_value
    current_value = record.current_value

    history_entries =
      case purchase_date do
        nil ->
          # Only a "today" snapshot when we don't know the original purchase date.
          [%{recorded_on: today, value: current_value}]

        _ ->
          # Start with a snapshot at purchase time using the initial value.
          entries = [%{recorded_on: purchase_date, value: initial_value}]

          # Avoid duplicate snapshots if the purchase date equals today and the value is the same.
          if purchase_date == today and Money.equal?(initial_value, current_value) do
            entries
          else
            entries ++ [%{recorded_on: today, value: current_value}]
          end
      end

    with :ok <- insert_history_entries(record.id, history_entries) do
      {:ok, record}
    end
  end

  @spec create_history_on_update(Changeset.t(), Ash.Resource.record()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_history_on_update(changeset, record) do
    if Changeset.changing_attribute?(changeset, :current_value) do
      # On value changes, append a new snapshot for today.
      today = Date.utc_today()

      with :ok <-
             insert_history_entries(record.id, [
               %{recorded_on: today, value: record.current_value}
             ]) do
        {:ok, record}
      end
    else
      {:ok, record}
    end
  end

  @spec insert_history_entries(Ecto.UUID.t(), list(map())) :: :ok | {:error, any()}
  defp insert_history_entries(investment_id, entries) do
    # Insert each snapshot and fail fast if any insert fails.
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      InvestmentHistory
      |> Ash.Changeset.for_create(:create, Map.put(entry, :investment_id, investment_id))
      |> Ash.create()
      |> case do
        {:ok, _history} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end
end

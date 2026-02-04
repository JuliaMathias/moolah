defmodule Moolah.Finance.Changes.TrackInvestmentOperation do
  @moduledoc """
  Creates an investment operation when the current value changes.

  By default, this change emits `:deposit` or `:withdraw` operations based on the
  delta sign. When used with `mode: :market_update`, it emits an `:update`
  operation and keeps the delta as-is.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.Investment
      ...>   |> Ash.Changeset.for_update(:update, %{current_value: Money.new(200, :BRL)})
      iex> changeset =
      ...>   Moolah.Finance.Changes.TrackInvestmentOperation.change(changeset, [], %{})
      iex> match?(%Ash.Changeset{}, changeset)
      true

      iex> changeset =
      ...>   Moolah.Finance.Investment
      ...>   |> Ash.Changeset.for_update(:market_update, %{current_value: Money.new(210, :BRL)})
      iex> changeset =
      ...>   Moolah.Finance.Changes.TrackInvestmentOperation.change(changeset, [mode: :market_update], %{})
      iex> match?(%Ash.Changeset{}, changeset)
      true
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Moolah.Finance.InvestmentOperation

  @impl true
  @spec change(Changeset.t(), keyword(), map()) :: Changeset.t()
  def change(changeset, opts, _context) do
    if Changeset.changing_attribute?(changeset, :current_value) do
      Changeset.after_action(changeset, fn _changeset, record ->
        create_operation(changeset, record, opts)
      end)
    else
      changeset
    end
  end

  @spec create_operation(Changeset.t(), Ash.Resource.record(), keyword()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_operation(changeset, record, opts) do
    mode = Keyword.get(opts, :mode, :delta)

    # Compute the delta between the previous and current values.
    old_value = changeset.data.current_value
    new_value = record.current_value

    with {:ok, delta} <- Money.sub(new_value, old_value),
         {:ok, _operation} <- insert_operation(record.id, delta, mode) do
      {:ok, record}
    else
      {:error, error} -> {:error, error}
    end
  end

  @spec insert_operation(Ecto.UUID.t(), Money.t(), atom()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp insert_operation(investment_id, delta, mode) do
    {type, value} = operation_payload(delta, mode)

    InvestmentOperation
    |> Ash.Changeset.for_create(:create, %{
      investment_id: investment_id,
      type: type,
      value: value
    })
    |> Ash.create()
  end

  @spec operation_payload(Money.t(), atom()) :: {atom(), Money.t()}
  defp operation_payload(delta, :market_update), do: {:update, delta}

  defp operation_payload(delta, _mode) do
    # Default behavior: use deposit/withdraw with an absolute value.
    case Decimal.compare(delta.amount, 0) do
      :gt -> {:deposit, abs_money(delta)}
      :lt -> {:withdraw, abs_money(delta)}
      :eq -> {:update, delta}
    end
  end

  @spec abs_money(Money.t()) :: Money.t()
  defp abs_money(%Money{amount: amount, currency: currency}) do
    Money.new(Decimal.abs(amount), currency)
  end
end

defmodule Moolah.Finance.Validations.ValidateOperationCurrency do
  @moduledoc """
  Ensures investment operation values use the same currency as the parent investment.

  The validation loads the investment referenced by `investment_id` and compares the
  operation `value` currency against the investment's `current_value` currency.
  If the investment cannot be loaded or the value is not a valid money struct,
  the validation returns `:ok` and allows other validations to handle the issue.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.InvestmentOperation
      ...>   |> Ash.Changeset.for_create(:create, %{
      ...>     investment_id: investment_id,
      ...>     type: :deposit,
      ...>     value: Money.new(100, :BRL)
      ...>   })
      iex> Moolah.Finance.Validations.ValidateOperationCurrency.validate(changeset, [], %{})
      :ok
  """

  use Ash.Resource.Validation

  alias Ash.Changeset
  alias Moolah.Finance.Investment

  @impl true
  @doc """
  Validates that the operation value currency matches the investment currency.

  Returns `:ok` when currencies align or when the investment cannot be loaded.
  Returns `{:error, field: :value, message: ...}` when currencies differ.
  """
  @spec validate(Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    investment_id =
      Changeset.get_attribute(changeset, :investment_id) || changeset.data.investment_id

    value = Changeset.get_attribute(changeset, :value) || changeset.data.value

    with {:ok, %Investment{} = investment} when not is_nil(investment_id) <-
           Ash.get(Investment, investment_id),
         {:ok, value_currency} <- get_currency(value),
         {:ok, investment_currency} <- get_currency(investment.current_value) do
      if to_string(value_currency) == to_string(investment_currency) do
        :ok
      else
        {:error,
         field: :value,
         message: "currency must match investment currency (#{investment_currency})"}
      end
    else
      _ -> :ok
    end
  end

  @spec get_currency(Money.t() | term()) :: {:ok, atom()} | {:error, :invalid_money}
  defp get_currency(%Money{currency: currency}), do: {:ok, currency}
  defp get_currency(_), do: {:error, :invalid_money}
end

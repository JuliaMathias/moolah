defmodule Moolah.Finance.Changes.CreateInvestmentOperationFromTransaction do
  @moduledoc """
  Creates investment operations for transfer transactions involving investment accounts.

  This change runs after a transaction is created or updated. If the transaction is a
  transfer and either the source or target account is an investment account, it will
  create an `InvestmentOperation` linked to the transaction. The operation type is
  determined by the transfer direction:

  - `:deposit` when the investment account is the target
  - `:withdraw` when the investment account is the source

  The investment is selected via `target_investment_id`, which must belong to the
  investment account involved in the transfer.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.Transaction
      ...>   |> Ash.Changeset.for_create(:create, %{
      ...>     transaction_type: :transfer,
      ...>     amount: Money.new(100, :BRL),
      ...>     account_id: bank_account_id,
      ...>     target_account_id: investment_account_id,
      ...>     target_investment_id: investment_id
      ...>   })
      iex> Moolah.Finance.Changes.CreateInvestmentOperationFromTransaction.change(changeset, [], %{})
      %Ash.Changeset{}
  """

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Moolah.Finance.InvestmentOperation
  alias Moolah.Ledger.Account

  @impl true
  @doc """
  Adds an after_action hook to create investment operations for applicable transfers.
  """
  @spec change(Changeset.t(), keyword(), map()) :: Changeset.t()
  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn _changeset, record ->
      create_operation_if_needed(record)
    end)
  end

  @spec create_operation_if_needed(Ash.Resource.record()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp create_operation_if_needed(record) do
    with :transfer <- record.transaction_type,
         {:ok, target_is_investment} <- investment_transfer?(record),
         {type, value} <- operation_details(record, target_is_investment),
         {:ok, _operation} <- insert_operation(record, type, value) do
      {:ok, record}
    else
      :skip -> {:ok, record}
      :not_transfer -> {:ok, record}
      {:error, error} -> {:error, error}
    end
  end

  @spec operation_details(Ash.Resource.record(), boolean()) :: {atom(), Money.t()}
  defp operation_details(record, target_is_investment) do
    # For transfers into an investment account, use the target amount.
    if target_is_investment do
      {:deposit, record.amount}
    else
      # For transfers out of an investment account, use source_amount when available.
      source_value = record.source_amount || record.amount
      {:withdraw, source_value}
    end
  end

  @spec investment_transfer?(Ash.Resource.record()) :: {:ok, boolean()} | :skip | {:error, any()}
  defp investment_transfer?(record) do
    source_is_investment = investment_account?(record.account_id)
    target_is_investment = investment_account?(record.target_account_id)

    cond do
      not source_is_investment and not target_is_investment ->
        :skip

      is_nil(record.target_investment_id) ->
        {:error, "target_investment_id is required for investment transfers"}

      true ->
        {:ok, target_is_investment}
    end
  end

  @spec insert_operation(Ash.Resource.record(), atom(), Money.t()) ::
          {:ok, Ash.Resource.record()} | {:error, any()}
  defp insert_operation(record, type, value) do
    InvestmentOperation
    |> Ash.Changeset.for_create(:create, %{
      investment_id: record.target_investment_id,
      transaction_id: record.id,
      type: type,
      value: value
    })
    |> Ash.create()
  end

  @spec investment_account?(Ecto.UUID.t() | nil) :: boolean()
  defp investment_account?(nil), do: false

  defp investment_account?(account_id) do
    case Ash.get(Account, account_id) do
      {:ok, %{account_type: :investment_account}} -> true
      _ -> false
    end
  end
end

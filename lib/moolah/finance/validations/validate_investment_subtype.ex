defmodule Moolah.Finance.Validations.ValidateInvestmentSubtype do
  @moduledoc """
  Ensures the investment subtype matches the selected investment type.

  This validation checks the `type`/`subtype` pairing against the supported
  Brazilian investment categories.

  ## Examples

      iex> changeset =
      ...>   Moolah.Finance.Investment
      ...>   |> Ash.Changeset.for_create(:create, %{type: :fundos, subtype: :multimercado})
      iex> Moolah.Finance.Validations.ValidateInvestmentSubtype.validate(changeset, [], %{})
      :ok
  """

  use Ash.Resource.Validation

  alias Ash.Changeset

  @subtypes_by_type %{
    renda_fixa: [:cdb, :lci_lca, :cri_cra, :debentures],
    fundos: [:renda_fixa, :multimercado],
    tesouro_direto: [:selic, :prefixado, :ipca],
    renda_variavel: [:fiis, :acoes]
  }

  @impl true
  @doc """
  Validates that a subtype is compatible with the selected type.

  Returns `:ok` when the pair is valid (or missing), otherwise returns a
  `{:error, field: :subtype, message: ...}` tuple.
  """
  @spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
  def validate(changeset, _opts, _context) do
    type = Changeset.get_attribute(changeset, :type) || changeset.data.type
    subtype = Changeset.get_attribute(changeset, :subtype) || changeset.data.subtype

    if is_nil(type) or is_nil(subtype) do
      :ok
    else
      valid_subtypes = Map.get(@subtypes_by_type, type, [])

      if subtype in valid_subtypes do
        :ok
      else
        {:error, field: :subtype, message: "is invalid for investment type #{type}"}
      end
    end
  end
end

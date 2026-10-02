defmodule Moolah.MoneyLocalizationTest do
  @moduledoc """
  Verifies the supported money locales after migrating from CLDR to Localize.
  """

  use ExUnit.Case, async: true

  test "money defaults to English formatting" do
    assert {:ok, "$1,234.56"} = Money.to_string(Money.new("1234.56", :USD))
  end

  test "money supports Brazilian Portuguese formatting" do
    assert {:ok, formatted} =
             Money.to_string(Money.new("1234.56", :BRL), locale: "pt-BR")

    assert String.replace(formatted, "\u00a0", " ") == "R$ 1.234,56"
  end
end

defmodule Moolah.Cldr do
  @moduledoc """
  CLDR (Common Locale Data Repository) configuration for Moolah.

  Provides internationalization and localization support including
  currency formatting, number formatting, and date/time localization.
  """

  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Number]
end

# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Moolah.Repo.insert!(%Moolah.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Budget Categories - Static reference data
# Using Ash.Seed for direct data layer access (bypasses actions)
# Based on AUVP financial education methodology

alias Moolah.Finance.BudgetCategory

categories = [
  %{
    name: "Fixed Costs",
    icon: "hero-home-solid",
    color: "#DC2626",
    description:
      "Everything you pay every month: rent, utilities, car insurance, financing installments - all fixed monthly expenses"
  },
  %{
    name: "Comfort",
    icon: "hero-sparkles-solid",
    color: "#059669",
    description:
      "Things that aren't really necessary but improve quality of life - like a luxury car when a regular one would suffice"
  },
  %{
    name: "Goals",
    icon: "hero-flag-solid",
    color: "#7C3AED",
    description:
      "Things you plan for: trips, major purchases, specific objectives you're saving toward"
  },
  %{
    name: "Pleasures",
    icon: "hero-heart-solid",
    color: "#EA580C",
    description:
      "Everything you spend having pleasure: drinks with friends, barbecues with family, entertainment, dining out"
  },
  %{
    name: "Financial Liberty",
    icon: "hero-trending-up-solid",
    color: "#0891B2",
    description: "Everything you invest for long-term wealth building and financial independence"
  },
  %{
    name: "Knowledge",
    icon: "hero-academic-cap-solid",
    color: "#BE185D",
    description: "What you spend on studies, courses, books, and personal development"
  }
]

IO.puts("Seeding budget categories...")

Enum.each(categories, fn category_data ->
  Ash.Seed.seed!(BudgetCategory, category_data)
  IO.puts("  ✓ Created: #{category_data.name}")
end)

IO.puts("Budget categories seeded successfully!")

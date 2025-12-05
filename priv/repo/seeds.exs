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

alias Moolah.Finance.BudgetCategory
alias Moolah.Finance.LifeAreaCategory

# Helper module for seeding resources safely
defmodule SeedHelper do
  @spec seed_resource(module(), map()) :: map()
  def seed_resource(resource, data) do
    try do
      record = Ash.Seed.seed!(resource, data)
      IO.puts("  ✓ Created: #{data.name}")
      # Return map with id and name for parent referencing
      %{id: record.id, name: record.name}
    rescue
      Ash.Error.Invalid ->
        # Resource already exists - verify existence and return just reference data
        # We need to find the existing record to get its ID if it's a parent
        {:ok, all_records} = Ash.read(resource)

        # Basic matching logic - extend if needed for other resources
        existing =
          Enum.find(all_records, fn record ->
            # Match by name and parent_id (if present in data)
            record.name == data.name and
              Map.get(record, :parent_id) == Map.get(data, :parent_id)
          end)

        IO.puts("  ○ Already exists: #{data.name}")

        if existing do
          %{id: existing.id, name: existing.name}
        else
          # Fallback if we can't find it but it failed creation (shouldn't happen ideally)
          %{id: nil, name: data.name}
        end
    end
  end
end

# ============================================================================
# BUDGET CATEGORIES
# ============================================================================

IO.puts("\nSeeding budget categories...")

budget_categories = [
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

Enum.each(budget_categories, fn data ->
  SeedHelper.seed_resource(BudgetCategory, data)
end)

IO.puts("Budget categories seeded successfully!")

# ============================================================================
# LIFE AREA CATEGORIES
# ============================================================================

IO.puts("\nSeeding life area categories...")

# --- Health ---
health =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Health",
    icon: "hero-heart-solid",
    color: "#10B981",
    description: "Physical and mental health expenses",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Medical",
    icon: "hero-beaker-solid",
    description: "Doctor visits, medications, treatments"
  },
  %{
    name: "Fitness",
    icon: "hero-bolt-solid",
    description: "Gym, personal training, sports equipment"
  },
  %{
    name: "Wellness",
    icon: "hero-sparkles-solid",
    description: "Massage, spa, mental health, therapy"
  },
  %{
    name: "Supplements",
    icon: "hero-cube-solid",
    description: "Vitamins, protein powder, health supplements"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: health.id,
      color: "#10B981",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Education ---
education =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Education",
    icon: "hero-academic-cap-solid",
    color: "#6366F1",
    description: "Learning and skill development",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Courses",
    icon: "hero-computer-desktop-solid",
    description: "Online courses, bootcamps, workshops"
  },
  %{
    name: "Books",
    icon: "hero-book-open-solid",
    description: "Books, ebooks, audiobooks, magazines"
  },
  %{
    name: "Certifications",
    icon: "hero-trophy-solid",
    description: "Professional certifications and exams"
  },
  %{
    name: "Conferences",
    icon: "hero-users-solid",
    description: "Tech conferences, seminars, networking events"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: education.id,
      color: "#6366F1",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Food ---
food =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Food",
    icon: "hero-cake-solid",
    color: "#F59E0B",
    description: "All food and dining expenses",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Groceries",
    icon: "hero-shopping-cart-solid",
    description: "Supermarket, fresh produce, household items"
  },
  %{
    name: "Restaurants",
    icon: "hero-building-storefront-solid",
    description: "Dining out, cafes, bars"
  },
  %{name: "Delivery", icon: "hero-truck-solid", description: "Food delivery, meal kits"},
  %{
    name: "Cafés & Snacks",
    icon: "hero-cup-paper-solid",
    description: "Coffee shops, bakeries, gelato, quick bites"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: food.id,
      color: "#F59E0B",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Transportation ---
transportation =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Transportation",
    icon: "hero-car-solid",
    color: "#8B5CF6",
    description: "Getting around the city",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Public Transport",
    icon: "hero-building-office-2-solid",
    description: "Bus, metro, train tickets"
  },
  %{
    name: "Ride Share",
    icon: "hero-device-phone-mobile-solid",
    description: "Uber, 99, taxi services"
  },
  %{name: "Fuel", icon: "hero-fire-solid", description: "Gasoline, car maintenance"},
  %{name: "Parking", icon: "hero-square-3-stack-3d-solid", description: "Parking fees, tolls"}
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: transportation.id,
      color: "#8B5CF6",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Entertainment ---
entertainment =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Entertainment",
    icon: "hero-musical-note-solid",
    color: "#EF4444",
    description: "Fun activities and hobbies",
    transaction_type: :debit,
    depth: 0
  })

[
  %{name: "Streaming", icon: "hero-tv-solid", description: "Netflix, Spotify, Disney+, etc."},
  %{
    name: "Events",
    icon: "hero-ticket-solid",
    description: "Concerts, theater, sports events, cinema"
  },
  %{
    name: "Hobbies",
    icon: "hero-puzzle-piece-solid",
    description: "Art supplies, instruments, hobby materials"
  },
  %{
    name: "Games",
    icon: "hero-device-tablet-solid",
    description: "Video games, board games, apps"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: entertainment.id,
      color: "#EF4444",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Travel ---
travel =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Travel",
    icon: "hero-airplane-solid",
    color: "#06B6D4",
    description: "Trips and travel expenses",
    transaction_type: :debit,
    depth: 0
  })

[
  %{name: "Domestic Travel", icon: "hero-map-solid", description: "Travel within Brazil"},
  %{
    name: "International Travel",
    icon: "hero-globe-americas-solid",
    description: "International trips"
  },
  %{
    name: "Accommodation",
    icon: "hero-home-modern-solid",
    description: "Hotels, Airbnb, hostels"
  },
  %{
    name: "Travel Food",
    icon: "hero-map-pin-solid",
    description: "Meals and drinks while traveling"
  },
  %{
    name: "Travel Insurance",
    icon: "hero-shield-check-solid",
    description: "Travel insurance coverage"
  },
  %{
    name: "Visa & Passport",
    icon: "hero-document-text-solid",
    description: "Visa fees, passport renewal"
  },
  %{
    name: "Currency Exchange",
    icon: "hero-currency-dollar-solid",
    description: "Foreign currency exchange fees"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: travel.id,
      color: "#06B6D4",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Shopping ---
shopping =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Shopping",
    icon: "hero-shopping-bag-solid",
    color: "#EC4899",
    description: "Personal items and retail purchases",
    transaction_type: :debit,
    depth: 0
  })

[
  %{name: "Clothing", icon: "hero-swatch-solid", description: "Clothes, shoes, accessories"},
  %{
    name: "Electronics",
    icon: "hero-computer-desktop-solid",
    description: "Gadgets, phones, computers"
  },
  %{
    name: "Personal Care",
    icon: "hero-scissors-solid",
    description: "Haircuts, skincare, cosmetics"
  },
  %{name: "Gifts", icon: "hero-gift-solid", description: "Presents for others"}
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: shopping.id,
      color: "#EC4899",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Home ---
home =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Home",
    icon: "hero-home-solid",
    color: "#84CC16",
    description: "Home-related expenses",
    transaction_type: :debit,
    depth: 0
  })

[
  %{name: "Rent", icon: "hero-building-office-solid", description: "Monthly rent or mortgage"},
  %{name: "Utilities", icon: "hero-bolt-solid", description: "Electricity, water, gas, internet"},
  %{
    name: "Maintenance",
    icon: "hero-wrench-screwdriver-solid",
    description: "Repairs, improvements, cleaning"
  },
  %{name: "Furniture", icon: "hero-chair-solid", description: "Furniture, decor, appliances"},
  %{
    name: "Mobile Phone",
    icon: "hero-device-phone-mobile-solid",
    description: "Mobile phone bill"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: home.id,
      color: "#84CC16",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Spirituality ---
spirituality =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Spirituality",
    icon: "hero-heart-hands-solid",
    color: "#F97316",
    description: "Spiritual and community activities",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Church",
    icon: "hero-building-library-solid",
    description: "Church donations, activities"
  },
  %{
    name: "Charity",
    icon: "hero-hand-raised-solid",
    description: "Donations to causes and charities"
  },
  %{
    name: "Community",
    icon: "hero-user-group-solid",
    description: "Community events, volunteering"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: spirituality.id,
      color: "#F97316",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Professional ---
professional =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Professional",
    icon: "hero-briefcase-solid",
    color: "#64748B",
    description: "Work-related expenses",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Equipment",
    icon: "hero-computer-desktop-solid",
    description: "Work tools, software, hardware"
  },
  %{
    name: "Networking",
    icon: "hero-users-solid",
    description: "Professional networking, meetups"
  },
  %{
    name: "Coworking",
    icon: "hero-building-office-solid",
    description: "Coworking spaces, office supplies"
  },
  %{
    name: "Professional Memberships",
    icon: "hero-identification-solid",
    description: "Professional associations, memberships"
  },
  %{
    name: "Business Travel",
    icon: "hero-airplane-solid",
    description: "Work-related travel expenses"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: professional.id,
      color: "#64748B",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Subscriptions ---
subscriptions =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Subscriptions",
    icon: "hero-rectangle-stack-solid",
    color: "#A855F7",
    description: "Recurring subscription services",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Software Subscriptions",
    icon: "hero-command-line-solid",
    description: "Adobe, Microsoft, development tools"
  },
  %{
    name: "Cloud Storage",
    icon: "hero-cloud-solid",
    description: "Google Drive, Dropbox, iCloud"
  },
  %{
    name: "Delivery Subscriptions",
    icon: "hero-truck-solid",
    description: "Mercado Livre, Clube iFood, Amazon Prime"
  },
  %{
    name: "Professional Services",
    icon: "hero-briefcase-solid",
    description: "Accounting, legal, consulting services"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: subscriptions.id,
      color: "#A855F7",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Personal Development ---
personal_dev =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Personal Development",
    icon: "hero-light-bulb-solid",
    color: "#14B8A6",
    description: "Personal growth and self-improvement",
    transaction_type: :debit,
    depth: 0
  })

[
  %{
    name: "Coaching & Mentoring",
    icon: "hero-user-group-solid",
    description: "Life coaching, career mentoring"
  },
  %{
    name: "Therapy & Counseling",
    icon: "hero-chat-bubble-left-right-solid",
    description: "Mental health therapy, counseling sessions"
  },
  %{
    name: "Personal Workshops",
    icon: "hero-presentation-chart-bar-solid",
    description: "Personal development workshops, seminars"
  },
  %{
    name: "Self-Improvement",
    icon: "hero-arrow-trending-up-solid",
    description: "Self-help materials, personal growth tools"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: personal_dev.id,
      color: "#14B8A6",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# --- Taxes & Fees ---
taxes =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Taxes & Fees",
    icon: "hero-document-text-solid",
    color: "#DC2626",
    description: "Government fees and financial charges",
    transaction_type: :debit,
    depth: 0
  })

[
  %{name: "Income Tax", icon: "hero-calculator-solid", description: "Income tax payments"},
  %{
    name: "Bank Fees",
    icon: "hero-building-library-solid",
    description: "Banking fees, account maintenance"
  },
  %{
    name: "Government Fees",
    icon: "hero-building-office-2-solid",
    description: "Document fees, certifications, government services"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: taxes.id,
      color: "#DC2626",
      transaction_type: :debit,
      depth: 1
    })
  )
end)

# ============================================================================
# CREDIT CATEGORIES (Income)
# ============================================================================

# --- Employment ---
employment =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Employment",
    icon: "hero-briefcase-solid",
    color: "#059669",
    description: "Job-related income",
    transaction_type: :credit,
    depth: 0
  })

[
  %{name: "Salary", icon: "hero-banknotes-solid", description: "Main job salary and bonuses"},
  %{
    name: "Freelance",
    icon: "hero-computer-desktop-solid",
    description: "Freelance work and consulting"
  },
  %{
    name: "Side Gigs",
    icon: "hero-device-phone-mobile-solid",
    description: "Part-time work, gig economy"
  },
  %{
    name: "Commission",
    icon: "hero-chart-bar-solid",
    description: "Sales commissions and performance bonuses"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: employment.id,
      color: "#059669",
      transaction_type: :credit,
      depth: 1
    })
  )
end)

# --- Investments ---
investments =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Investments",
    icon: "hero-trending-up-solid",
    color: "#7C2D12",
    description: "Investment-related income",
    transaction_type: :credit,
    depth: 0
  })

[
  %{
    name: "Dividends",
    icon: "hero-currency-dollar-solid",
    description: "Stock dividends, FIIs earnings"
  },
  %{
    name: "Appreciation",
    icon: "hero-chart-pie-solid",
    description: "Asset value increase (realized)"
  },
  %{name: "Rent Income", icon: "hero-home-solid", description: "Income from rental properties"},
  %{name: "Interest", icon: "hero-banknotes-solid", description: "Savings interest, bond yields"}
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: investments.id,
      color: "#7C2D12",
      transaction_type: :credit,
      depth: 1
    })
  )
end)

# --- Gifts & Benefits ---
gifts =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Gifts & Benefits",
    icon: "hero-gift-solid",
    color: "#DB2777",
    description: "Unexpected income and benefits",
    transaction_type: :credit,
    depth: 0
  })

[
  %{
    name: "Gifts Received",
    icon: "hero-envelope-solid",
    description: "Cash gifts from family/friends"
  },
  %{name: "Refunds", icon: "hero-arrow-path-solid", description: "Tax refunds, purchase returns"},
  %{name: "Sale of Items", icon: "hero-tag-solid", description: "Selling personal items used"}
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: gifts.id,
      color: "#DB2777",
      transaction_type: :credit,
      depth: 1
    })
  )
end)

# --- Other Income ---
other_income =
  SeedHelper.seed_resource(LifeAreaCategory, %{
    name: "Other Income",
    icon: "hero-plus-circle-solid",
    color: "#4B5563",
    description: "Miscellaneous income sources",
    transaction_type: :credit,
    depth: 0
  })

[
  %{
    name: "Uncategorized",
    icon: "hero-question-mark-circle-solid",
    description: "Income not fitting other categories"
  },
  %{
    name: "Loans Received",
    icon: "hero-hand-raised-solid",
    description: "Personal loans received (liability)"
  }
]
|> Enum.each(fn cat ->
  SeedHelper.seed_resource(
    LifeAreaCategory,
    Map.merge(cat, %{
      parent_id: other_income.id,
      color: "#4B5563",
      transaction_type: :credit,
      depth: 1
    })
  )
end)

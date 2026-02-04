# Moolah 💰

 **Moolah** is a modern, high-performance personal finance application designed to help users take control of their financial life. Built on the robust **Elixir** and **Phoenix** ecosystem, it leverages the power of the **Ash Framework** to provide a flexible, scalable, and secure foundation for managing money.

Whether you're tracking daily expenses, managing budget categories, or planning for long-term financial liberty, Moolah provides the tools you need with a premium, responsive user interface.

---

## 🧰 Devcontainer (Optional)

This repo includes a Dev Container configuration for a reproducible Elixir/Erlang/Node environment with Postgres.

1. Install Docker and the VS Code Dev Containers extension.
2. Open the repo in VS Code and choose **Reopen in Container**.
3. The container will run:
   - `mix deps.get`
   - `mix assets.setup`
   - `mix ash.setup --quiet`

The Dev Container is opt-in and does not affect your normal local workflow.
If you update `.vscode/extensions.json`, run `scripts/sync-devcontainer-extensions.sh` to keep the devcontainer extension list in sync.

## 🏗️ Technological Foundation: Ash Framework

Moolah is architected using **Ash Framework**, a declarative, resource-oriented framework for building applications in Elixir. Unlike traditional MVC frameworks where you write imperative code for every layer, Ash allows us to *model* our domain logic and derive the rest.

### Why Ash?

- **Declarative Design**: We describe *what* our application does (resources, relationships, policies) rather than *how* to do it. This reduces boilerplate and ensures consistency.

- **Resource-Oriented**: The core building blocks are **Resources** (e.g., `Account`, `BudgetCategory`). These are not just database tables but rich entities with defined behaviors.

- **Automated Interfaces**: Ash automatically generates potent APIs (Elixir, GraphQL, JSON:API) from our resource definitions, allowing us to focus on business logic.

### Core Concepts in Moolah

1. **Resources**: These are the primary entities. For example, `Moolah.Finance.BudgetCategory` defines the data structure for categories, including attributes like `name` and `color`.
2. **Actions**: We verify all interactions through defined **Actions** (Read, Create, Update, Destroy). This ensures that every data change goes through a secure, validated path (e.g., specific rules for creating a Transaction).
3. **Extensions**: Moolah utilizes powerful Ash extensions to handle complex domains:
   - `ash_double_entry`: Implements a rigorous double-entry bookkeeping system for error-free financial tracking.
   - `ash_money` & `ex_money`: Handles multi-currency operations with precision.
   - `ash_authentication`: Manages secure user registration and login flows.
   - `ash_admin`: Provides an auto-generated admin dashboard for system management.

---

## 🚀 Key Features (Implemented)

### 📊 Budget Management

- **Methodology-Based Categories**: Implements fixed budget categories inspired by the AUVP financial education methodology:

  - **Fixed Costs**: Essential monthly expenses (Rent, Utilities).
  - **Comfort**: Quality of life improvements.
  - **Goals**: Short and long-term objectives.
  - **Pleasures**: Entertainment and leisure.
  - **Financial Liberty**: Investments for the future.
  - **Knowledge**: Education and personal development.

- **Visual Identity**: Each category allows for custom icons and color coding for easy visual recognition.

### 🗂️ Life Area Categorization

- **Hierarchical Structure**: Supports a 2-level hierarchy (Parent -> Child) for organizing expenditure areas (e.g., "Housing" -> "Maintenance").

- **Validation**: Built-in rules to prevent circular references and ensure data integrity.

### 🏦 Account Management

- **Multi-Type Support**: Distinguish between different financial vessels:

  - **Bank Accounts**: Standard checking/savings.
  - **Money Accounts**: Cash or physical wallets.
  - **Investment Accounts**: For brokerage and asset holdings.

- **Secure Ledger**: Underlying double-entry system ensures that every cent is accounted for.

---

## 🗺️ Roadmap

We are actively developing Moolah. Here is what is coming next:

- [ ] **Transaction Management**:
  - Comprehensive UI for entering credits, debits, and transfers.
  - Advanced browsing and filtering capabilities.
- [ ] **Investment Tracking**:
  - Dedicated history and operations tracking.
  - Performance metrics and asset distribution tools.
- [ ] **Tagging System**: Flexible tag system for cross-category organization.
- [ ] **Enhanced UI**: Continuing to polish the frontend with `Phoenix LiveView` and `Tailwind CSS` for a world-class user experience.

---

## 🛠️ Technology Stack

- **Language**: [Elixir](https://elixir-lang.org/) (v1.16+)
- **Web Framework**: [Phoenix](https://www.phoenixframework.org/) (v1.7+) & **LiveView** (v0.20+)
- **Application Framework**: [Ash Framework](https://www.ash-hq.org/) (v3.0)
- **Styling**: [Tailwind CSS](https://tailwindcss.com/)
- **Database**: PostgreSQL
- **Job Processing**: Oban

---

## 💻 Setup & Development

### Prerequisites

- Elixir 1.19+
- Erlang/OTP 28+
- PostgreSQL 14+
- Node.js (for asset management)

### Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/JuliaMathias/moolah.git
   cd moolah
   ```

2. **Run the setup script**:
   This will install dependencies, setup the database, and run seeds.

   ```bash
   mix setup
   ```

3. **Start the Server**:

   ```bash
   mix phx.server
   ```

   You can now visit [`localhost:4000`](http://localhost:4000) in your browser.

### Useful Commands

- `mix test`: Run the test suite.
- `mix format`: Format the codebase.
- `mix ash.codegen`: Generate Ash migrations after resource changes.
- `mix ash_postgres.create`: Create the database storage.

### Testing & Coverage

Moolah uses **ExCoveralls** for test coverage reporting. To measure and improve coverage:

```bash
# Run tests with coverage summary
MIX_ENV=test mix coveralls

# Generate detailed line-by-line coverage
MIX_ENV=test mix coveralls.detail

# Filter coverage to specific files
MIX_ENV=test mix coveralls.detail --filter lib/moolah/finance

# Generate HTML coverage report (opens in browser)
MIX_ENV=test mix coveralls.html
# Then open: cover/excoveralls.html
```

The test suite includes comprehensive coverage of:
- ✅ Validation modules (hierarchy depth, circular references, safe deletion)
- ✅ Change modules (tag normalization, slug generation)
- ✅ Action modules (find-or-create patterns)
- ✅ Ledger modules (balance tracking, transfer operations)
- ✅ Business logic and edge cases

For more details on test coverage, see the [ExCoveralls documentation](https://github.com/parroty/excoveralls).

---

Built with ❤️ by [Julia Mathias](https://github.com/JuliaMathias).

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup
- `mix setup` - Install dependencies, setup Ash resources, build assets, and run seeds
- `mix deps.get` - Install Elixir dependencies
- `mix ash.setup` - Setup Ash resources and database

### Server
- `mix phx.server` - Start Phoenix server on port 4000
- `iex -S mix phx.server` - Start server with IEx console

### Testing
- `mix test` - Run all tests (automatically runs `mix ash.setup --quiet` first)
- `mix coveralls.github` - Generate test coverage report

### Code Quality
- `mix format` - Format code
- `mix format --check-formatted` - Check if code is formatted
- `mix compile --warnings-as-errors` - Compile with warnings as errors
- `mix credo --strict` - Run static code analysis
- `mix dialyzer --no-check` - Run type checking (requires PLT setup first)
- `mix dialyzer --plt` - Create/update PLT files (stored in priv/plts)

### Assets
- `mix assets.setup` - Install Tailwind and ESBuild if missing
- `mix assets.build` - Build CSS and JS assets
- `mix assets.deploy` - Build minified assets for production

### Database
- `mix ecto.setup` - Create database, run migrations, and seed data
- `mix ecto.reset` - Drop and recreate database

## Architecture Overview

### Phoenix Application Structure
This is a Phoenix 1.7+ application with:
- **Multiple Phoenix Endpoints**: Main endpoint, CMS endpoint, and Proxy endpoint
- **Ash Framework**: Primary data layer using Ash domains for business logic
- **Beacon CMS**: Content management system integration
- **Authentication**: Ash Authentication with Phoenix integration
- **Background Jobs**: Oban for job processing
- **UI Components**: Mishka Chelekom component library + custom Phoenix components

### Key Domains
- **Moolah.Ledger** (`lib/moolah/ledger.ex`): Double-entry bookkeeping with Account, Balance, and Transfer resources
- **Moolah.Accounts** (`lib/moolah/accounts.ex`): User management with User and Token resources

### Important Dependencies
- **Ash Framework**: `ash`, `ash_postgres`, `ash_phoenix`, `ash_admin` - Main data layer
- **Authentication**: `ash_authentication`, `ash_authentication_phoenix`
- **Ledger**: `ash_double_entry`, `ash_money` - Financial transaction handling
- **Background Jobs**: `oban`, `ash_oban`
- **CMS**: `beacon`, `beacon_live_admin`
- **UI**: `mishka_chelekom`, extensive custom components in `lib/moolah_web/components/`
- **Assets**: `tailwind`, `esbuild`, `heroicons`

### File Structure Patterns
- `lib/moolah/` - Core business logic and Ash domains
- `lib/moolah_web/` - Phoenix web layer with extensive component library
- `lib/moolah_web/components/` - Large collection of reusable UI components
- `config/` - Environment-specific configuration
- `assets/` - Frontend assets (CSS, JS)
- `priv/` - Static assets, database files, gettext translations

### Development Notes
- Uses Ash.Domain instead of traditional Phoenix contexts
- Extensive use of LiveView components
- Multi-tenant architecture preparation with Ash
- Financial data handled through specialized Ash extensions
- Component-heavy architecture with pre-built UI elements

### CI/CD
The project includes GitHub Actions workflow (`.github/workflows/ci.yml`) that runs:
- Formatting checks
- Compilation with warnings as errors
- Credo static analysis
- Dialyzer type checking
- Full test coverage with coveralls
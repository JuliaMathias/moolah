# Moolah - GitHub Copilot Instructions

Welcome to **Moolah**, a modern personal finance application built with Elixir, Phoenix, and the Ash Framework. This document provides essential onboarding information for GitHub Copilot coding agents working on this repository.

## Quick Start

### Setup Commands

```bash
# Full setup (dependencies, database, assets, seeds)
mix setup

# Start development server
mix phx.server

# Run tests
mix test

# Pre-commit checks (format, compile, test, credo, coverage)
mix precommit
```

### Development Workflow

1. **After making changes**: Always run `mix format` (auto-formats Elixir code)
2. **Before committing**: Run `mix precommit` to verify all checks pass
3. **To test specific file**: `mix test test/path/to/test_file.exs`
4. **To rerun failed tests**: `mix test --failed`

## Technology Stack

- **Language**: Elixir 1.19+ on Erlang/OTP 28+
- **Web Framework**: Phoenix 1.7+ with LiveView 1.1+
- **Application Framework**: Ash Framework 3.0 (declarative, resource-oriented)
- **Database**: PostgreSQL 14+ (via Ecto and ash_postgres)
- **Styling**: Tailwind CSS v4 (no tailwind.config.js, uses @import syntax)
- **Assets**: ESBuild for JS, Tailwind for CSS
- **Authentication**: ash_authentication + ash_authentication_phoenix
- **Ledger**: ash_double_entry + ash_money for double-entry bookkeeping
- **Background Jobs**: Oban + ash_oban
- **UI Components**: Mishka Chelekom library + extensive custom components
- **Testing**: ExUnit + Phoenix.LiveViewTest + LazyHTML + ExCoveralls

## Project Architecture

### Key Domains

- **Moolah.Ledger** (`lib/moolah/ledger.ex`): Double-entry bookkeeping (Account, Balance, Transfer)
- **Moolah.Accounts** (`lib/moolah/accounts.ex`): User management (User, Token)
- **Moolah.Finance**: Budget categories, life areas, transactions, investments

### Directory Structure

- `lib/moolah/` - Core business logic and Ash domains
- `lib/moolah_web/` - Phoenix web layer (LiveViews, controllers, components)
- `lib/moolah_web/components/` - Large collection of reusable UI components
- `config/` - Environment-specific configuration
- `assets/` - Frontend assets (JS in assets/js, CSS in assets/css)
- `priv/` - Static assets, database files, gettext translations
- `test/` - Test files (mirrors lib/ structure)

### Ash Framework

This project uses **Ash Framework**, which is declarative and resource-oriented:

- **Resources** are the core entities (not just DB tables)
- **Actions** define all interactions (Create, Read, Update, Destroy)
- **Extensions** add powerful functionality (ash_double_entry, ash_money, ash_authentication)
- We use `Ash.Domain` modules instead of traditional Phoenix contexts

## Code Style & Best Practices

### Documentation Requirements

- **ALWAYS add `@spec` for ALL functions** (public and private)
- **ALWAYS add `@doc` for public functions** (except standard callbacks like `change/3` and migration `up/down`)
- **ALWAYS add `@moduledoc`** to all modules (especially detailed for migrations)
- Use `iex>` style for examples in docs
- Private functions should have explanatory comments when necessary

Example:
```elixir
@doc """
Validates that a category does not create a circular reference.

## Parameters
- changeset: The changeset being validated
- opts: Validation options

## Returns
- `:ok` if valid
- `{:error, keyword()}` if validation fails
"""
@spec validate(Ash.Changeset.t(), keyword()) :: :ok | {:error, keyword()}
def validate(changeset, opts) do
  # implementation
end
```

### Elixir Guidelines

- **Lists**: Do NOT use `mylist[i]` - use `Enum.at(mylist, i)` or pattern matching
- **Variable rebinding**: Must bind result of block expressions (`socket = if ...`)
- **No nested modules**: Keep one module per file to avoid cyclic dependencies
- **Struct access**: Use `struct.field` not `struct[:field]` (structs don't implement Access by default)
- **String to atom**: Never use `String.to_atom/1` on user input (memory leak risk)
- **Predicate functions**: End with `?`, avoid `is_` prefix (reserve for guards)
- **No elsif**: Elixir has no `elsif` - use `cond` or `case` for multiple conditionals
- **HTTP library**: Use `:req` (Req) library - avoid `:httpoison`, `:tesla`, `:httpc`

### Phoenix & LiveView Guidelines

#### General Phoenix

- Router `scope` blocks provide module aliasing - no need for extra `alias` in routes
- `Phoenix.View` is deprecated - don't use it
- Templates use `~H` sigil or `.heex` files - never `~E`

#### LiveView Specifics

- **Forms**: Use `Phoenix.Component.form/1` and `Phoenix.Component.to_form/2`
  ```elixir
  assign(socket, form: to_form(...))
  # Template: <.form for={@form} id="unique-id">
  ```
- **Navigation**: Use `<.link navigate={href}>` / `<.link patch={href}>` (not deprecated `live_redirect`/`live_patch`)
- **Naming**: LiveViews end in `Live` suffix (e.g., `MoolahWeb.DashboardLive`)
- **Streams**: ALWAYS use streams for collections (not regular assigns)
  - Append: `stream(socket, :items, [new_item])`
  - Reset: `stream(socket, :items, [new_item], reset: true)`
  - Delete: `stream_delete(socket, :items, item)`
  - Template: `<div id="items" phx-update="stream">` with `:for={{id, item} <- @streams.items} id={id}`
- **Avoid LiveComponent** unless absolutely necessary

#### HEEx Templates

- **Interpolation**: Use `{...}` in attributes, `<%= ... %>` for blocks in body
  ```heex
  <div id={@id}>             <!-- Correct -->
    <%= if @condition do %>  <!-- Correct -->
      {@value}               <!-- Correct -->
    <% end %>
  </div>
  
  <!-- NEVER: <div id="<%= @id %>"> -->
  ```
- **Classes**: Use list syntax for multiple classes
  ```heex
  <a class={[
    "px-2 text-white",
    @flag && "py-5",
    if(@cond, do: "border-red", else: "border-blue")
  ]}>
  ```
- **Lists**: Use `<%= for item <- @list do %>` (not `<% Enum.each %>`)
- **Comments**: Use `<%!-- comment --%>` (HEEx syntax)
- **No inline scripts**: Never write `<script>` tags in templates - put JS in `assets/js/`
- **DOM IDs**: Always add unique IDs to key elements (forms, buttons) for testing

### Testing

- Use `Phoenix.LiveViewTest` module for LiveView tests
- **ALWAYS use component helpers** from `test/support/component_helpers.ex`:
  - `find_one/2` - Find single element (raises if 0 or multiple)
  - `value/2` - Get form input value
  - `attribute/2,3` - Get element attribute
  - `text/1,2` - Get text content
  - `has_element?/2` - Check element exists (boolean)
  - `count_elements/2` - Count matching elements
- **Avoid regex** for HTML testing (`html =~ ~s(value="foo")` ❌ use `value/2` ✅)
- Test outcomes, not implementation details
- Reference element IDs from templates in tests
- Use LazyHTML for parsing and selectors

### UI/UX & Design

- Use **Tailwind CSS** for styling (no daisyUI - build custom components)
- Tailwind v4 uses new import syntax in `app.css`:
  ```css
  @import "tailwindcss" source(none);
  @source "../css";
  @source "../js";
  @source "../../lib/moolah_web";
  ```
- Avoid using `@apply` in raw CSS - prefer utility classes directly in templates
- Check `lib/moolah_web/components/` for existing components before creating new ones
- Use `<.icon name="hero-x-mark">` for icons (imported from `core_components.ex`)
- Use `<.input>` component for form inputs (imported from `core_components.ex`)
- Focus on world-class UI with micro-interactions, smooth transitions, clean typography

### Assets & JS

- Only `app.js` and `app.css` bundles supported
- Import vendor dependencies into app.js/app.css (don't link external scripts)
- Never write inline `<script>` tags in templates
- Write JS hooks in `assets/js/` and integrate via `assets/js/app.js`
- If using `phx-hook`, also set `phx-update="ignore"` when hook manages own DOM

## CI/CD Pipeline

The GitHub Actions CI workflow (`.github/workflows/ci.yml`) runs:

1. Format check: `mix format --check-formatted`
2. Compilation: `mix compile --warnings-as-errors`
3. Static analysis: `mix credo --strict`
4. Type checking: `mix dialyzer --format github`
5. Tests with coverage: `mix coveralls.github`

Ensure all checks pass locally before pushing by running `mix precommit`.

## Common Patterns

### Error Handling

- Use `{:ok, result}` / `{:error, reason}` tuples
- Prefer `with` statements over bare pattern matching:
  ```elixir
  with {:ok, result} <- some_function() do
    # handle success
  else
    {:error, reason} -> {:error, reason}
    unexpected -> {:error, {:unexpected_result, unexpected}}
  end
  ```

### Component Reuse

Before building new UI elements:
1. Search `lib/moolah_web/components/` for existing components
2. Check Mishka Chelekom library components
3. Extend existing components rather than duplicating

### Memory Management

- Use LiveView streams for collections (prevents memory ballooning)
- Streams are not enumerable - refetch and reset with `reset: true` to filter

## Debugging & Tools

- `iex -S mix phx.server` - Start server with IEx console
- `mix ash.codegen` - Generate Ash migrations after resource changes
- `mix coveralls.html` - Generate HTML coverage report
- `mix dialyzer --plt` - Create/update PLT files (stored in `priv/plts`)
- Server runs on port 4000: `http://localhost:4000`

## Important Notes

- This is an **Ash Framework** application - it uses declarative resources, not imperative code
- Financial operations use **double-entry bookkeeping** via ash_double_entry
- Authentication flows are handled by **ash_authentication**
- Background jobs are processed by **Oban**
- Multi-tenant architecture is prepared but not fully implemented yet

## When Stuck

1. Check this file first for project-specific conventions
2. Review `AGENTS.md` for comprehensive Phoenix/Elixir guidelines
3. Review `CLAUDE.md` for development commands and architecture details
4. Run `mix help <task>` to understand available Mix tasks
5. Use `mix ash.info <Resource>` to inspect Ash resources

## Trust the Instructions

These instructions are maintained to be accurate and current. Only search the codebase if information here is incomplete or you encounter errors that contradict these guidelines. When in doubt, follow these conventions for consistency across the project.

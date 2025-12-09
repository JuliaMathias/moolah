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

## Code Style Guidelines

### Documentation and Type Specifications

- **ALWAYS add @spec for ALL public functions** - Include parameter types and return types
- **ALWAYS add @spec for ALL private functions** - Helps with type checking and documentation
- **ALWAYS add @doc for public functions** - Explain what the function does, parameters, and return values
- Use @moduledoc for all modules to explain their purpose
- Include examples in documentation where helpful

**Example:**

```elixir
@doc """
Validates that a category does not create a circular reference.

## Parameters
- changeset: The changeset being validated
- opts: Validation options
- context: The validation context

## Returns
- `:ok` if valid
- `{:error, keyword()}` if validation fails
"""
@spec validate(Ash.Changeset.t(), keyword(), map()) :: :ok | {:error, keyword()}
def validate(changeset, opts, context) do
  # implementation
end
```

### CI/CD

The project includes GitHub Actions workflow (`.github/workflows/ci.yml`) that runs:

- Formatting checks
- Compilation with warnings as errors
- Credo static analysis
- Dialyzer type checking
- Full test coverage with coveralls

## Elixir Best Practices

### Error Handling

- Use `{:ok, result}` / `{:error, reason}` tuples in Elixir
- Prefer `with` statements over pattern matching that could crash:

  ```elixir
  # Good - handles errors gracefully
  with {:ok, result} <- some_function() do
    # handle success
  else
    {:error, reason} -> {:error, reason}
    unexpected -> {:error, {:unexpected_result, unexpected}}
  end

  # Avoid - crashes on unexpected results
  {:ok, result} = some_function()
  ```

- GraphQL errors return structured error responses
- Frontend uses Apollo error handling with user-friendly messages

### Using Existing Components

**ALWAYS check for existing components before building new UI elements.**

Before implementing any UI component or form element:

1. **Search the codebase first**:

   ```bash
   # For LiveView components
   grep -r "def component_name" lib/moolah_web/components/

   # For React components (if applicable)
   find assets/js/src/components -name "*.tsx"
   ```

2. **Common reusable components**:
   - Check `lib/moolah_web/components/` for existing components
   - Review Mishka Chelekom library components
   - Look for form inputs, buttons, modals, and other UI elements

3. **If you need to extend a component**:
   - Add new attributes to the existing component
   - Add tests in `test/moolah_web/components/`
   - This keeps the codebase DRY and maintains consistency

### Testing LiveView Components

**ALWAYS use component helpers from `test/support/component_helpers.ex` for LiveView tests.**

The component helpers provide robust, DOM-aware test utilities that are more reliable than regex matching or string inspection. They properly parse HTML using LazyHTML and provide clear error messages when elements aren't found.

#### Available Component Helpers

- `find_one/2` - Find a single element with CSS selector (raises if 0 or multiple found)
- `find/2` - Find multiple elements with CSS selector
- `value/2` - Get form input value (works with input/select/textarea/radio/checkbox)
- `attribute/2,3` - Get element attribute value
- `text/1,2` - Get text content from element
- `has_element?/2` - Check if element exists (boolean)
- `count_elements/2` - Count matching elements

#### When to Use Component Helpers

✅ **Use component helpers for:**

- Checking if elements exist: `find_one(html, "input[name='query']")`
- Reading form values: `value(html, "input[name='query']")`
- Reading attributes: `attribute(html, "form", "phx-change")`
- Reading text content: `text(html, ".error-message")`
- Counting elements: `count_elements(html, ".list-item")`

❌ **Avoid using regex for:**

- Form values: `html =~ ~s(value="foo")` → Use `value/2` instead
- Attributes: `html =~ ~s(phx-change="search")` → Use `attribute/3` instead
- Element existence: `html =~ "<input"` → Use `find_one/2` instead

#### Examples

```elixir
# ❌ Don't use regex for form values
assert html =~ ~s(value="Support")
refute html =~ ~s(value="Support")

# ✅ Use component helpers
assert value(html, ~s|input[name="action_option_query"]|) == "Support"
assert value(html, ~s|input[name="action_option_query"]|) in [nil, ""]

# ❌ Don't use regex for attributes
assert html =~ ~s(placeholder="Search options...")

# ✅ Use component helpers
assert find_one(html, ~s|input[placeholder="Search options…"]|)
# OR
assert attribute(html, "input", "placeholder") == "Search options…"

# ❌ Don't check for nil unnecessarily
assert find_one(html, "input[name='query']") != nil

# ✅ find_one already raises if not found
assert find_one(html, "input[name='query']")

# ✅ Use element/2 for interactions with unique selectors
view
|> element("form[id='form-action_option_query']")
|> render_change(%{"action_option_query" => "search term"})
```

#### Benefits of Component Helpers

1. **More reliable**: Properly parses HTML structure instead of string matching
2. **Better error messages**: Clear indication of what went wrong (element not found, multiple matches, etc.)
3. **Type-safe**: Returns proper Elixir types (strings, nil, etc.) instead of boolean matches
4. **Maintainable**: Changes to whitespace or attribute order won't break tests
5. **Readable**: Intent is clearer than regex patterns

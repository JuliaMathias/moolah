# Setting Up the Environment for Automation Tools

This guide explains how to configure your devcontainer so that automation tools (like GitHub Copilot agents) can run commands like `mix format`, even in restricted network environments.

## Problem

Automation tools running in GitHub Actions face network restrictions that prevent:
- Installing Hex package manager
- Downloading dependencies
- Running `mix format` (which needs dependencies for import_deps)

## Solutions

### Solution 1: Pre-install Hex in Docker Image ✅ **EASIEST**

This is the minimal change that solves 90% of problems.

**Update `.devcontainer/Dockerfile`:**

```dockerfile
FROM elixir:1.19.5-otp-28

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    inotify-tools \
  && rm -rf /var/lib/apt/lists/*

# ⭐ NEW: Install Hex and Rebar before creating user
RUN mix local.hex --force && \
    mix local.rebar --force

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
  && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
  && mkdir -p /workspaces \
  && chown -R ${USERNAME}:${USERNAME} /workspaces
```

**Benefits:**
- ✅ Hex available immediately
- ✅ No runtime network calls for Hex
- ✅ Works in restricted environments
- ✅ Still need network for `mix deps.get` (but that's cached in CI)

**Limitations:**
- ⚠️ Still can't run `mix format` if it needs import_deps (requires actual dependencies)

---

### Solution 2: Pre-install Dependencies in Docker Image ✅ **MORE COMPLETE**

This makes `mix format` work everywhere, even without network access.

**Update `.devcontainer/Dockerfile`:**

```dockerfile
FROM elixir:1.19.5-otp-28

# System dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    inotify-tools \
  && rm -rf /var/lib/apt/lists/*

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# ⭐ NEW: Pre-install project dependencies
WORKDIR /tmp/build
COPY mix.exs mix.lock ./
RUN mix deps.get && \
    mix deps.compile

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
  && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
  && mkdir -p /workspaces \
  && chown -R ${USERNAME}:${USERNAME} /workspaces

# Copy pre-compiled dependencies to user's home
RUN mkdir -p /home/${USERNAME}/.mix && \
    cp -r /root/.mix/* /home/${USERNAME}/.mix/ && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.mix
```

**Update `.devcontainer/postCreate.sh`:**

```bash
#!/usr/bin/env bash
set -euo pipefail

DB_HOST="${DB_HOST:-db}"

wait_for_db() {
  local retries=30
  local count=0

  until (echo >"/dev/tcp/${DB_HOST}/5432") >/dev/null 2>&1; do
    count=$((count + 1))
    if [ "$count" -ge "$retries" ]; then
      echo "Postgres did not become ready in time (host: ${DB_HOST})."
      return 1
    fi
    sleep 1
  done
}

echo "Waiting for Postgres on ${DB_HOST}:5432..."
wait_for_db

# ⭐ NEW: Copy pre-built dependencies if they don't exist
if [ ! -d "deps" ] && [ -d "/tmp/build/deps" ]; then
  echo "Copying pre-built dependencies..."
  cp -r /tmp/build/deps .
  cp -r /tmp/build/_build .
fi

# Run setup
mix devcontainer.setup
```

**Benefits:**
- ✅ `mix format` works without network
- ✅ Fast container startup (deps already compiled)
- ✅ Automation tools can format code
- ✅ Works in restricted environments

**Trade-offs:**
- ⚠️ Larger Docker image (~200-500MB more)
- ⚠️ Need to rebuild image when dependencies change
- ⚠️ Build takes longer initially

---

### Solution 3: Simplified Formatter Config (No Dependencies) ✅ **QUICK FIX**

If you don't need dependency-specific formatting rules, simplify `.formatter.exs`:

**Update `.formatter.exs`:**

```elixir
[
  # ⭐ REMOVED: import_deps (requires downloading dependencies)
  # import_deps: [:ash_double_entry, :ash_oban, ...],
  
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
```

**Benefits:**
- ✅ `mix format` works with just Hex installed
- ✅ No need to pre-install dependencies
- ✅ Smaller Docker image

**Trade-offs:**
- ⚠️ Lose dependency-specific formatting rules
- ⚠️ May format code differently than dependencies expect
- ⚠️ Not recommended if you use Ash/Phoenix extensively

---

## Recommended Approach

### For This Repository: **Solution 2** (Pre-install Dependencies)

Since you're using Ash Framework extensively and your `.formatter.exs` imports many dependencies, Solution 2 is best:

1. **Keeps all formatting rules** from dependencies
2. **Works everywhere** including automation tools
3. **Faster development** experience (no waiting for deps)

### Implementation Steps

1. **Update `.devcontainer/Dockerfile`** with Solution 2 code above
2. **Update `.devcontainer/postCreate.sh`** with Solution 2 code above
3. **Rebuild the devcontainer:**
   ```bash
   docker compose -f .devcontainer/docker-compose.yml build --no-cache
   ```
4. **Test it works:**
   ```bash
   docker compose -f .devcontainer/docker-compose.yml up -d
   docker compose -f .devcontainer/docker-compose.yml exec app mix format --check-formatted
   ```

---

## Alternative: Use `.tool-versions` with asdf

If developers use asdf locally, you could also create a setup that works both locally and in containers:

**Create `script/setup` script:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install dependencies if missing
if command -v asdf &> /dev/null; then
  echo "Installing asdf plugins..."
  asdf plugin add erlang || true
  asdf plugin add elixir || true
  asdf install
fi

# Install Hex and Rebar
mix local.hex --force
mix local.rebar --force

# Get dependencies
mix deps.get

# Setup database
mix ecto.setup

echo "✅ Setup complete!"
```

Make it executable:
```bash
chmod +x script/setup
```

Then developers and automation can run: `./script/setup`

---

## Testing Your Changes

After implementing Solution 2, you can verify it works:

```bash
# Start fresh container
docker compose -f .devcontainer/docker-compose.yml down -v
docker compose -f .devcontainer/docker-compose.yml build --no-cache
docker compose -f .devcontainer/docker-compose.yml up -d

# Test commands work without network
docker compose -f .devcontainer/docker-compose.yml exec app mix --version
docker compose -f .devcontainer/docker-compose.yml exec app mix format --check-formatted
docker compose -f .devcontainer/docker-compose.yml exec app mix compile

# Should all succeed! ✅
```

---

## Summary

**Quick win:** Implement Solution 1 (pre-install Hex) - 5 minutes
**Full solution:** Implement Solution 2 (pre-install dependencies) - 15 minutes
**Trade-off:** Implement Solution 3 (remove import_deps) - 2 minutes but loses formatting rules

I recommend **Solution 2** for your Ash-based project. It will enable automation tools to run all mix commands, including `mix format`, even in restricted network environments.

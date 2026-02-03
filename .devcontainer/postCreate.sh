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

mix deps.get
mix assets.setup
mix ash.setup --quiet

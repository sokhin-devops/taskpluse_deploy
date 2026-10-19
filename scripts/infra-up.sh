#!/usr/bin/env bash
# Starts the services next to the cluster (infra/compose.yaml): Nexus and
# PostgreSQL. Safe to re-run. Run from WSL after scripts/kind-up.sh:
#     bash scripts/infra-up.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! docker network inspect kind >/dev/null 2>&1; then
    echo "No 'kind' Docker network yet - run: bash scripts/kind-up.sh" >&2
    exit 1
fi

# The database admin password: random, local, never in git (infra/secrets/ is
# git-ignored). Kept if it already exists - PostgreSQL only reads it the first
# time it creates its data, so changing the file later changes nothing.
mkdir -p infra/secrets
if [ ! -s infra/secrets/postgres_admin_password ]; then
    (umask 077 && openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32 \
        > infra/secrets/postgres_admin_password)
    echo "Created infra/secrets/postgres_admin_password (git-ignored)"
fi

docker compose -f infra/compose.yaml up -d
docker compose -f infra/compose.yaml ps

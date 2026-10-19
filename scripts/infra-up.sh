#!/usr/bin/env bash
# Starts the services next to the cluster (infra/compose.yaml): Nexus, Jenkins
# and PostgreSQL. Safe to re-run. Run from WSL after scripts/kind-up.sh and
# `source scripts/session.sh` (the vault password is needed):
#     bash scripts/infra-up.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
: "${ANSIBLE_VAULT_PASSWORD_FILE:?run: source scripts/session.sh}"

if ! docker network inspect kind >/dev/null 2>&1; then
    echo "No 'kind' Docker network yet - run: bash scripts/kind-up.sh" >&2
    exit 1
fi

mkdir -p infra/secrets

# The database admin password: random, local, never in git (infra/secrets/ is
# git-ignored). Kept if it already exists - PostgreSQL only reads it the first
# time it creates its data, so changing the file later changes nothing.
if [ ! -s infra/secrets/postgres_admin_password ]; then
    (umask 077 && openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32 \
        > infra/secrets/postgres_admin_password)
    echo "Created infra/secrets/postgres_admin_password (git-ignored)"
fi

# Jenkins' secrets come from the vault, rewritten at every run so the vault
# stays the truth. They reach Jenkins as Docker secrets (files), not variables.
vault_value() {
    ansible-vault view inventory/group_vars/all/vault.yml | sed -n "s/^$1: \"\(.*\)\"$/\1/p"
}
for pair in "jenkins_admin_password:vault_jenkins_admin_password" \
            "nexus_push_password:vault_nexus_jenkins_password"; do
    file="infra/secrets/${pair%%:*}"
    value="$(vault_value "${pair#*:}")"
    if [ -z "$value" ]; then
        echo "${pair#*:} is not in the vault - run: bash scripts/vault-add-app-secrets.sh" >&2
        exit 1
    fi
    (umask 077 && printf '%s' "$value" > "$file")
done

# The group that owns the Docker socket, as seen inside containers - Jenkins is
# added to it instead of running as root.
DOCKER_GID="$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock alpine:3.22 stat -c %g /var/run/docker.sock)"
export DOCKER_GID
echo "Docker socket group inside containers: $DOCKER_GID"

docker compose -f infra/compose.yaml build
docker compose -f infra/compose.yaml up -d
docker compose -f infra/compose.yaml ps

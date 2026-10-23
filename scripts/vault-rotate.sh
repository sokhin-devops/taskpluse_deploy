#!/usr/bin/env bash
# Replaces ONE generated secret in the vault with a new random value - for when
# a password may have been seen (printed, pasted, logged) or on a schedule.
# Run from the repo root after `source scripts/session.sh`:
#     bash scripts/vault-rotate.sh vault_nexus_jenkins_password
#
# This only changes the vault. Then apply it where the secret is used, e.g. for
# a Nexus account: playbooks/setup-local-registry.yml (resets the Nexus user to
# the vault's value) and scripts/infra-up.sh (hands it to Jenkins).
#
# The decrypted vault only ever exists in a pipe; nothing plain is written to
# disk, and the new value is never printed.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
vault=inventory/group_vars/all/vault.yml
: "${ANSIBLE_VAULT_PASSWORD_FILE:?run: source scripts/session.sh}"
key="${1:?usage: vault-rotate.sh <vault key, e.g. vault_nexus_jenkins_password>}"

case "$key" in
    vault_*) ;;
    *) echo "Expected a vault key starting with vault_, got '$key'" >&2; exit 2 ;;
esac

# Letters and digits only: no quoting surprises in YAML, SQL or URLs.
random() { openssl rand -base64 "$1" | tr -dc 'A-Za-z0-9' | cut -c1-"$2"; }

current="$(ansible-vault view "$vault")"
if ! grep -q "^${key}: " <<<"$current"; then
    echo "$key is not in the vault - nothing to rotate." >&2
    exit 1
fi

case "$key" in
    # The API needs at least 32 characters (256 bits for HS256).
    vault_jwt_secret_*) value="$(random 96 64)" ;;
    *)                  value="$(random 48 32)" ;;
esac

# Swap only that one line; every other key stays exactly as it was.
sed "s|^${key}: .*|${key}: \"${value}\"|" <<<"$current" \
    | env -u ANSIBLE_VAULT_PASSWORD_FILE ansible-vault encrypt \
        --vault-password-file "$ANSIBLE_VAULT_PASSWORD_FILE" --output "$vault.new"
mv "$vault.new" "$vault"
echo "Rotated $key in the vault (new value not shown)."

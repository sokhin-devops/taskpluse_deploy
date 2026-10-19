#!/usr/bin/env bash
# Adds TaskPluse's per-environment secrets to the vault - database password and
# JWT signing key for staging and prod - generating any that are missing.
# Existing values are kept. Run from the repo root after `source scripts/session.sh`:
#     bash scripts/vault-add-app-secrets.sh
#
# The decrypted vault only ever exists in a pipe; nothing plain is written to disk.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
vault=inventory/group_vars/all/vault.yml
: "${ANSIBLE_VAULT_PASSWORD_FILE:?run: source scripts/session.sh}"

# Letters and digits only: no quoting surprises in YAML, SQL or URLs.
random() { openssl rand -base64 "$1" | tr -dc 'A-Za-z0-9' | cut -c1-"$2"; }

current="$(ansible-vault view "$vault")"
added=()
additions=""
for env in staging prod; do
    for key in "vault_db_password_${env}" "vault_jwt_secret_${env}"; do
        if grep -q "^${key}:" <<<"$current"; then
            continue
        fi
        case "$key" in
            vault_db_password_*) value="$(random 48 32)" ;;
            # The API needs at least 32 characters (256 bits for HS256).
            vault_jwt_secret_*)  value="$(random 96 64)" ;;
        esac
        additions+="${key}: \"${value}\""$'\n'
        added+=("$key")
    done
done

if [ "${#added[@]}" -eq 0 ]; then
    echo "Nothing to add - all app secrets are already in the vault."
    exit 0
fi

printf '%s\n%s' "$current" "$additions" \
    | env -u ANSIBLE_VAULT_PASSWORD_FILE ansible-vault encrypt \
        --vault-password-file "$ANSIBLE_VAULT_PASSWORD_FILE" --output "$vault.new"
mv "$vault.new" "$vault"
echo "Added to the vault: ${added[*]}"

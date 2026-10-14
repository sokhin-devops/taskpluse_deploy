#!/usr/bin/env bash
# Creates inventory/group_vars/all/vault.yml: every secret the playbooks need,
# encrypted with Ansible Vault. Run once, from the repo root:
#     bash scripts/create-vault.sh
#
# The Cloudflare token is read without echo; the passwords are generated. None
# of them is shown on screen or written to disk unencrypted - the plain text
# only ever exists in a pipe into `ansible-vault encrypt`.
#
# The encrypted file is committed to git. The vault password that unlocks it is
# not: it lives in ~/.ansible/taskpluse-vault-pass and in your password manager.
# Lose both and the secrets are gone - regenerate them and run this again.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vault_file="$repo_root/inventory/group_vars/all/vault.yml"
pass_file="$HOME/.ansible/taskpluse-vault-pass"

if [ -e "$vault_file" ]; then
    echo "$vault_file already exists. Change it with: ansible-vault edit $vault_file" >&2
    exit 1
fi

if [ ! -f "$pass_file" ]; then
    mkdir -p "$(dirname "$pass_file")"
    (umask 077 && openssl rand -base64 32 > "$pass_file")
    echo "Created the vault password file: $pass_file"
    echo "Save its content in your password manager now:  cat $pass_file"
fi

read -rsp "Cloudflare API token: " cf_token && echo
# Cloudflare API tokens are 40 characters; anything much shorter is a mis-paste.
if [ "${#cf_token}" -lt 30 ]; then
    echo "Got ${#cf_token} characters - that isn't a Cloudflare API token. Nothing was written." >&2
    exit 1
fi

# Letters and digits only: no quoting surprises in YAML, URLs or shell.
password() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }

{
    echo "---"
    echo "# Encrypted with Ansible Vault (scripts/create-vault.sh)."
    echo "#   read:  ansible-vault view inventory/group_vars/all/vault.yml"
    echo "#   edit:  ansible-vault edit inventory/group_vars/all/vault.yml"
    echo "vault_cloudflare_dns_api_token: \"$cf_token\""
    echo "vault_nexus_admin_password: \"$(password)\""
    echo "vault_nexus_jenkins_password: \"$(password)\""
    echo "vault_nexus_k8s_password: \"$(password)\""
} | env -u ANSIBLE_VAULT_PASSWORD_FILE \
    ansible-vault encrypt --vault-password-file "$pass_file" --output "$vault_file"
# env -u: after `source scripts/session.sh` the same password file is also set
# in ANSIBLE_VAULT_PASSWORD_FILE, and ansible-vault refuses to encrypt when it is
# offered two passwords, even identical ones.

echo "Created $vault_file (encrypted). First line:"
head -n 1 "$vault_file"

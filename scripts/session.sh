# Prepares one WSL shell to drive the TaskPluse infrastructure.
#
# Source it from the repo root - don't run it, or the settings die with the
# subshell:
#     source scripts/session.sh
#
# Nothing here is written to disk: the SSH key stays encrypted on disk while
# ssh-agent holds the unlocked copy for this shell.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ansible only reads ./ansible.cfg from the current directory, and skips it if
# that directory is world-writable (as /mnt drives are on a default WSL setup).
# Naming it here makes this repo's settings apply from any directory.
export ANSIBLE_CONFIG="$repo_root/ansible.cfg"

# ssh-add -l exits 2 when no agent is reachable, 1 when the agent holds no keys.
ssh-add -l >/dev/null 2>&1
if [ $? -eq 2 ]; then
    eval "$(ssh-agent -s)" >/dev/null
fi
if ! ssh-add -l 2>/dev/null | grep -q "taskpluse-vultr-admin"; then
    ssh-add "$HOME/.ssh/taskpluse_vultr"
fi

# Unlocks inventory/group_vars/all/vault.yml (made by scripts/create-vault.sh)
# without a password prompt on every run.
if [ -f "$HOME/.ansible/taskpluse-vault-pass" ]; then
    export ANSIBLE_VAULT_PASSWORD_FILE="$HOME/.ansible/taskpluse-vault-pass"
    echo "ANSIBLE_VAULT_PASSWORD_FILE=$ANSIBLE_VAULT_PASSWORD_FILE"
fi

# kubectl on this machine: the cluster-admin config saved by setup-kubernetes.yml.
if [ -f "$HOME/.kube/taskpluse.conf" ]; then
    export KUBECONFIG="$HOME/.kube/taskpluse.conf"
    echo "KUBECONFIG=$KUBECONFIG"
fi

# Docker Desktop has its own Kubernetes; a shell without this session talks to
# that one instead. Say which cluster kubectl and helm will act on.
context="$(kubectl config current-context 2>/dev/null || echo none)"
if [ "$context" = "kind-taskpluse" ]; then
    echo "kubectl context: $context"
else
    echo "WARNING: kubectl context is '$context', not kind-taskpluse - commands would go to the wrong cluster" >&2
fi

echo "ANSIBLE_CONFIG=$ANSIBLE_CONFIG"
ssh-add -l | grep "taskpluse-vultr-admin"

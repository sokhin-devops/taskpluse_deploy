# Prepares one WSL shell to drive the TaskPluse infrastructure.
#
# Source it from the repo root - don't run it, or the settings die with the
# subshell:
#     source scripts/session.sh
#
# Nothing here is written to disk: the API key lives only in this shell, and the
# SSH key stays encrypted on disk while ssh-agent holds the unlocked copy.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ansible only reads ./ansible.cfg from the current directory, and skips it if
# that directory is world-writable (as /mnt drives are on a default WSL setup).
# Naming it here makes this repo's settings apply from any directory.
export ANSIBLE_CONFIG="$repo_root/ansible.cfg"

# A Vultr API key is 36 upper-case letters and digits. Anything else is a
# mis-paste (empty, half a key, whatever else was on the clipboard), so it is
# caught here rather than as a 401 from the API later. A wrong value left over
# from an earlier attempt fails this check too, which brings the prompt back.
vultr_key_format='^[A-Z0-9]{36}$'
if ! [[ "${VULTR_API_KEY:-}" =~ $vultr_key_format ]]; then
    read -rsp "Vultr API key: " VULTR_API_KEY && echo
    if ! [[ "$VULTR_API_KEY" =~ $vultr_key_format ]]; then
        echo "That isn't a Vultr API key: got ${#VULTR_API_KEY} characters, expected 36 letters/digits." >&2
        echo "Copy it again from Vultr -> API, then run: source scripts/session.sh" >&2
        unset VULTR_API_KEY
        return 1
    fi
    export VULTR_API_KEY
fi

# ssh-add -l exits 2 when no agent is reachable, 1 when the agent holds no keys.
ssh-add -l >/dev/null 2>&1
if [ $? -eq 2 ]; then
    eval "$(ssh-agent -s)" >/dev/null
fi
if ! ssh-add -l 2>/dev/null | grep -q "taskpluse-vultr-admin"; then
    ssh-add "$HOME/.ssh/taskpluse_vultr"
fi

# kubectl on this machine: the cluster-admin config saved by setup-kubernetes.yml.
if [ -f "$HOME/.kube/taskpluse.conf" ]; then
    export KUBECONFIG="$HOME/.kube/taskpluse.conf"
    echo "KUBECONFIG=$KUBECONFIG"
fi

echo "ANSIBLE_CONFIG=$ANSIBLE_CONFIG"
echo "VULTR_API_KEY loaded (${#VULTR_API_KEY} characters)"
ssh-add -l | grep "taskpluse-vultr-admin"

#!/usr/bin/env bash
# Builds the local platform's cluster from git: kind nodes, Calico, Traefik, and
# the registry setting on every node. Safe to re-run - each part is skipped if
# it is already there. Run from WSL:
#     bash scripts/kind-up.sh
# Start over with:  kind delete cluster --name taskpluse
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
export KUBECONFIG="$HOME/.kube/taskpluse.conf"

cluster=taskpluse
calico_version=3.32.2
traefik_chart_version=41.6.1
calico_url="https://raw.githubusercontent.com/projectcalico/calico/v${calico_version}/manifests"

echo "== cluster"
if kind get clusters 2>/dev/null | grep -qx "$cluster"; then
    echo "kind cluster '$cluster' already exists"
else
    kind create cluster --config cluster/kind/kind-config.yaml --kubeconfig "$KUBECONFIG"
fi

echo "== registry setting on each node"
for node in $(kind get nodes --name "$cluster"); do
    docker exec "$node" mkdir -p /etc/containerd/certs.d/localhost:5001
    docker exec -i "$node" sh -c 'cat > /etc/containerd/certs.d/localhost:5001/hosts.toml' \
        < cluster/kind/registry-hosts.toml
    echo "$node: localhost:5001 -> $(grep '^server' cluster/kind/registry-hosts.toml)"
done

echo "== Calico ${calico_version}"
kubectl get crd installations.operator.tigera.io >/dev/null 2>&1 \
    || kubectl create -f "${calico_url}/operator-crds.yaml" >/dev/null
kubectl get namespace tigera-operator >/dev/null 2>&1 \
    || kubectl create -f "${calico_url}/tigera-operator.yaml"
kubectl wait --for=condition=Established --timeout=120s crd/installations.operator.tigera.io
kubectl get installation default >/dev/null 2>&1 \
    || kubectl apply -f cluster/calico/installation.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=600s

echo "== Traefik (chart ${traefik_chart_version})"
helm repo add traefik https://traefik.github.io/charts --force-update >/dev/null
helm upgrade --install traefik traefik/traefik --version "$traefik_chart_version" \
    --namespace traefik --create-namespace -f cluster/traefik/values.yaml --wait

echo "== check"
kubectl get nodes
curl -s -o /dev/null -w "http://127.0.0.1/ -> HTTP %{http_code} (404 = Traefik answering)\n" http://127.0.0.1/

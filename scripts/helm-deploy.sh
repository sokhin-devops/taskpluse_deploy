#!/usr/bin/env bash
# Deploys ONE app's image to one environment with Helm; the other app keeps the
# image it is running now. The taskpluse-deploy Jenkins job runs this, and it
# works the same by hand (after `source scripts/session.sh`):
#     bash scripts/helm-deploy.sh staging api 6-32fa074
#
# Uses whatever KUBECONFIG points at - in Jenkins that's the namespace-only
# deployer for this environment, so a mistake can't reach the other one.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

usage="usage: helm-deploy.sh <staging|prod> <api|web> <image tag>"
env="${1:?$usage}"
app="${2:?$usage}"
tag="${3:?$usage}"

case "$env" in staging|prod) ;; *) echo "$usage" >&2; exit 2 ;; esac
case "$app" in
    api) other=web ;;
    web) other=api ;;
    *) echo "$usage" >&2; exit 2 ;;
esac
# Docker's tag rules - and nothing that could smuggle in another --set.
if [[ ! "$tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
    echo "Not a valid image tag: '$tag'" >&2
    exit 2
fi

release=taskpluse
ns="taskpluse-${env}"

# The other app's tag, read from its Deployment - what is really running, not
# what some file says. Helm needs both tags on every upgrade.
if ! other_image="$(kubectl -n "$ns" get deployment "${release}-${other}" \
        -o jsonpath='{.spec.template.spec.containers[0].image}')"; then
    echo "No ${release}-${other} Deployment in ${ns}. Install both apps once by hand first (see learning_notebook.md, Phase 9)." >&2
    exit 1
fi
other_tag="${other_image##*:}"

echo "Deploying ${app}:${tag} to ${ns} (${other} stays at ${other_tag})"

# --wait=watcher: return only when every new Pod is Ready (for the API that
# includes the database check). --rollback-on-failure: if they never get
# Ready, put the previous release back - the environment is never left broken.
helm upgrade --install "$release" helm/taskpluse -n "$ns" \
    -f "helm/taskpluse/values-${env}.yaml" \
    --set "${app}.image.tag=${tag}" \
    --set "${other}.image.tag=${other_tag}" \
    --set-string "deployedBy=${DEPLOYED_BY:-manual}" \
    --wait=watcher --rollback-on-failure --timeout 5m

kubectl -n "$ns" get deployments \
    -o custom-columns='DEPLOYMENT:.metadata.name,READY:.status.readyReplicas,WANTED:.spec.replicas,IMAGE:.spec.template.spec.containers[0].image'
helm history "$release" -n "$ns" --max 3

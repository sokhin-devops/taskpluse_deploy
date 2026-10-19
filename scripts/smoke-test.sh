#!/usr/bin/env bash
# Checks a deployed environment from the outside, along the same path a user
# takes (Cloudflare -> tunnel -> Traefik -> the app). Fast, and touches no data.
#     bash scripts/smoke-test.sh https://taskpluse-staging.sokhin.site
set -uo pipefail

url="${1:?usage: smoke-test.sh <base url>}"
url="${url%/}"
failed=0

# --retry covers a brief 502/503 while Traefik picks up the new Pods.
http() { curl -s --max-time 15 --retry 3 --retry-delay 2 "$@"; }

expect() {  # <what> <expected> <actual>
    if [ "$3" = "$2" ]; then
        echo "ok    $1 ($3)"
    else
        echo "FAIL  $1: expected $2, got $3"
        failed=1
    fi
}

# The web app is served, and it's the Angular app.
expect "web: home page"   200 "$(http -o /dev/null -w '%{http_code}' "$url/")"
expect "web: /healthz"    200 "$(http -o /dev/null -w '%{http_code}' "$url/healthz")"
expect "web: Angular app" yes "$(http "$url/" | grep -q '<app-root' && echo yes || echo no)"

# The API answers through the Ingress, behind authentication.
expect "api: tasks need a login" 401 "$(http -o /dev/null -w '%{http_code}' "$url/api/tasks")"

# A full login round trip with a user that doesn't exist: the API looks it up
# in the database and says 401. Sent like a browser (with Origin), so a CORS
# mistake shows up here as 403 - see the Phase 10 CORS bug.
expect "api: login checks the database (CORS ok)" 401 "$(http -o /dev/null -w '%{http_code}' \
    -X POST "$url/api/auth/login" \
    -H 'Content-Type: application/json' -H "Origin: $url" \
    -d '{"email":"smoke-test@invalid.example","password":"not-a-real-password"}')"

# Actuator stays internal: /actuator/* goes to the web app, not the API.
expect "api: actuator not public" no "$(http "$url/actuator/health" | grep -q '"status"' && echo yes || echo no)"

if [ "$failed" -ne 0 ]; then
    echo "Smoke test FAILED for $url"
    exit 1
fi
echo "Smoke test passed for $url"

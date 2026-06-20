#!/usr/bin/env bash
# Smoke-test a SlipStream dev server end-to-end WITHOUT the app: reachability,
# portal login with the dev creds, and one authenticated poll endpoint. This is
# the completion criterion for "server is up in the right state".
#
# Usage: smoke.sh [BASE_URL]
#   BASE_URL  defaults to $SLIPSTREAM_BASE_URL, else http://localhost:8080
#             (physical device: pass http://<your-mac>.local:8080)
# Credentials from $SLIPSTREAM_DEV_USERNAME / $SLIPSTREAM_DEV_PIN (default tester / 1234).
set -uo pipefail

base="${1:-${SLIPSTREAM_BASE_URL:-http://localhost:8080}}"
base="${base%/}"
user="${SLIPSTREAM_DEV_USERNAME:-tester}"
pin="${SLIPSTREAM_DEV_PIN:-1234}"
fail=0

echo "Smoke-testing $base (user: $user)"

# 1. Reachability + portal status (public, no auth).
if curl -fsS --max-time 5 "$base/api/v1/status" >/dev/null 2>&1; then
  echo "  ok   GET /api/v1/status reachable"
else
  echo "  FAIL GET /api/v1/status — is 'make dev' running and reachable at $base?"
  fail=1
fi

# 2. Portal login -> token.
token=""
if [ "$fail" -eq 0 ]; then
  login_json=$(curl -fsS --max-time 5 -X POST "$base/api/v1/requests/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"$user\",\"password\":\"$pin\"}" 2>/dev/null) || login_json=""
  token=$(printf '%s' "$login_json" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("token",""))' 2>/dev/null || true)
  if [ -n "$token" ]; then
    echo "  ok   POST /api/v1/requests/auth/login → token"
  else
    echo "  FAIL login returned no token — check dev user '$user' / PIN, and that server dev mode is ON"
    fail=1
  fi
fi

# 3. One authenticated poll endpoint.
if [ -n "$token" ]; then
  if curl -fsS --max-time 5 "$base/api/v1/requests/inbox/count" \
      -H "Authorization: Bearer $token" >/dev/null 2>&1; then
    echo "  ok   GET /api/v1/requests/inbox/count (authenticated)"
  else
    echo "  FAIL GET /api/v1/requests/inbox/count with token"
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "✓ Server smoke test passed — app sign-in should work against $base."
else
  echo "✗ Smoke test failed — fix the above before launching the app."
fi
exit "$fail"

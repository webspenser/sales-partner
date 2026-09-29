#!/usr/bin/env bash
# Runs this agent's tests. Structure is checked by the builder's validator
# (CI: webspenser/agent-builder/validate@v2).
set -uo pipefail
cd "$(dirname "$0")/.."
STATUS=0
echo "== content"; tests/test-content.sh || STATUS=1
echo "== policies"; tests/test-policies.sh || STATUS=1
[ "$STATUS" -eq 0 ] && echo "ALL GREEN" || echo "FAILURES ABOVE"
exit "$STATUS"

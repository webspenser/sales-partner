# Minimal assertion helpers. No external test framework.
PASS_COUNT=0
FAIL_COUNT=0

_report() { # _report <ok|no> <label>
  if [ "$1" = ok ]; then
    PASS_COUNT=$((PASS_COUNT + 1)); echo "  ok   $2"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL $2"
  fi
}

assert_pass() { # assert_pass <cmd...> — expect exit 0
  if "$@" >/dev/null 2>&1; then _report ok "exit 0: $*"
  else _report no "expected exit 0: $*"; fi
}

assert_fail() { # assert_fail <cmd...> — expect non-zero exit
  if "$@" >/dev/null 2>&1; then _report no "expected non-zero: $*"
  else _report ok "non-zero: $*"; fi
}

assert_contains() { # assert_contains <file> <string>
  if grep -qF -- "$2" "$1" 2>/dev/null; then _report ok "$1 contains '$2'"
  else _report no "$1 missing '$2'"; fi
}

assert_not_contains() { # assert_not_contains <file> <string>
  if grep -qF -- "$2" "$1" 2>/dev/null; then _report no "$1 still contains '$2'"
  else _report ok "$1 free of '$2'"; fi
}

finish() {
  echo "-- $PASS_COUNT passed, $FAIL_COUNT failed"
  [ "$FAIL_COUNT" -eq 0 ]
}

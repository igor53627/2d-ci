#!/usr/bin/env bash
# Refresh README badges (test count + group count) from the live integration suite.
#
# Source of truth for the main report:
#   - test count comes from `mix test test/chain/integration_test.exs` (the suite the page renders)
#   - group count is the number of <div class="group" id="group-N"> blocks in index.html
#
# AC #6 in TASK-26.9: README badges remain attached to the main integration suite.
# Bridge subsystem is reported on its own page with its own counter; it does NOT
# move these badges.
#
# Usage:
#   bash scripts/update-badges.sh                 # auto-detects sibling repo at ../2d
#   CHAIN_REPO=/path/to/2d bash scripts/update-badges.sh
#
# Exits non-zero on any failure so CI can gate on it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CI_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CHAIN_REPO="${CHAIN_REPO:-$(cd "$CI_REPO/../2d" 2>/dev/null && pwd || echo "")}"

if [[ -z "$CHAIN_REPO" || ! -d "$CHAIN_REPO" ]]; then
  echo "error: chain repo not found. Set CHAIN_REPO=/path/to/2d." >&2
  exit 2
fi

INTEGRATION_TEST="$CHAIN_REPO/test/chain/integration_test.exs"
INDEX_HTML="$CI_REPO/index.html"
README="$CI_REPO/README.md"

[[ -f "$INTEGRATION_TEST" ]] || { echo "error: $INTEGRATION_TEST missing" >&2; exit 2; }
[[ -f "$INDEX_HTML" ]]       || { echo "error: $INDEX_HTML missing" >&2; exit 2; }
[[ -f "$README" ]]            || { echo "error: $README missing" >&2; exit 2; }

echo "→ chain repo:  $CHAIN_REPO"
echo "→ index.html:  $INDEX_HTML"
echo "→ README:      $README"
echo

# --- 1. Test count from `mix test` -------------------------------------------
echo "→ running mix test test/chain/integration_test.exs ..."
MIX_OUT="$(cd "$CHAIN_REPO" && mix test test/chain/integration_test.exs 2>&1)" || {
  echo "error: mix test failed:" >&2
  echo "$MIX_OUT" >&2
  exit 1
}

# Summary line shape: "56 tests, 0 failures" (optionally with "(N excluded)" or "N properties, ").
# Don't use `tail -1` — ExUnit may append "Randomized with seed ..." after the summary.
# Use `tests?` / `failures?` so the singular forms ("1 test", "1 failure") also match.
# `|| true` keeps the assignment alive under `set -euo pipefail` when grep returns
# 1 on no-match, so the empty-checks below are actually reachable.
SUMMARY="$(echo "$MIX_OUT" | grep -E '[0-9]+ tests?,' | tail -1 || true)"
TESTS="$(echo "$SUMMARY" | grep -oE '[0-9]+ tests?' | head -1 | grep -oE '[0-9]+' || true)"
FAILURES="$(echo "$SUMMARY" | grep -oE '[0-9]+ failures?' | head -1 | grep -oE '[0-9]+' || true)"

if [[ -z "${TESTS:-}" ]]; then
  echo "error: could not parse test count from: $SUMMARY" >&2
  exit 1
fi

if [[ -z "${FAILURES:-}" ]]; then
  echo "error: could not parse failure count from: $SUMMARY" >&2
  exit 1
fi

if [[ "$FAILURES" != "0" ]]; then
  echo "error: $FAILURES failures in main integration suite — refusing to bump badges" >&2
  exit 1
fi

echo "  tests:    $TESTS"
echo "  failures: $FAILURES"

# --- 2. Group count from index.html ------------------------------------------
# NB: do NOT use the variable name `GROUPS` — that's a bash readonly built-in
# array (user's group IDs); `$GROUPS` resolves to the primary GID, not what
# you assigned. Use GROUP_COUNT instead.
GROUP_COUNT="$(grep -cE '<div class="group" id="group-[0-9]+"' "$INDEX_HTML" || echo 0)"
if ! [[ "$GROUP_COUNT" =~ ^[0-9]+$ ]] || [[ "$GROUP_COUNT" -eq 0 ]]; then
  echo "error: could not parse group count from $INDEX_HTML (got: '$GROUP_COUNT')" >&2
  exit 1
fi
echo "  groups:   $GROUP_COUNT  (from $(basename "$INDEX_HTML"))"

# --- 3. Patch README badge URLs in place -------------------------------------
# Badge URL shape: tests-N%20passing-brightgreen   /   groups-N-blue
# Hard-fail if the badge patterns aren't present, so a future README rewrite
# can't make `sed` silently no-op and reach the "already up to date" path.
grep -qE 'tests-[0-9]+%20passing-brightgreen' "$README" || {
  echo "error: tests badge pattern not found in $README" >&2
  exit 1
}
grep -qE 'groups-[0-9]+-blue' "$README" || {
  echo "error: groups badge pattern not found in $README" >&2
  exit 1
}

TMP="$(mktemp)"
sed -E \
  -e "s|tests-[0-9]+%20passing-brightgreen|tests-${TESTS}%20passing-brightgreen|g" \
  -e "s|groups-[0-9]+-blue|groups-${GROUP_COUNT}-blue|g" \
  "$README" > "$TMP"

README_CHANGED=0
if ! cmp -s "$README" "$TMP"; then
  mv "$TMP" "$README"
  README_CHANGED=1
else
  rm -f "$TMP"
fi

# --- 4. Patch the on-page counters in index.html so the report matches the badge.
# The header has two `<div class="num">N</div>` cells driven by the test count
# (Tests + Passing). We don't touch the Groups/Failing/Runtime cells.
# Rendered shape (one per line):
#   <div class="stat"><div class="num">51</div><div class="label"><span class="en">Tests</span>...
#   <div class="stat"><div class="num">51</div><div class="label" style="color:#3fb950"><span class="en">Passing</span>...
INDEX_TMP="$(mktemp)"
sed -E \
  -e "s|(<div class=\"stat\"><div class=\"num\">)[0-9]+(</div><div class=\"label\"><span class=\"en\">Tests</span>)|\1${TESTS}\2|g" \
  -e "s|(<div class=\"stat\"><div class=\"num\">)[0-9]+(</div><div class=\"label\" style=\"color:#3fb950\"><span class=\"en\">Passing</span>)|\1${TESTS}\2|g" \
  "$INDEX_HTML" > "$INDEX_TMP"

INDEX_CHANGED=0
if ! cmp -s "$INDEX_HTML" "$INDEX_TMP"; then
  mv "$INDEX_TMP" "$INDEX_HTML"
  INDEX_CHANGED=1
else
  rm -f "$INDEX_TMP"
fi

echo
if [[ "$README_CHANGED" -eq 0 && "$INDEX_CHANGED" -eq 0 ]]; then
  echo "✓ README and index.html already up to date ($TESTS tests / $GROUP_COUNT groups)."
  exit 0
fi

[[ "$README_CHANGED" -eq 1 ]] && echo "✓ README updated   → $TESTS tests / $GROUP_COUNT groups"
[[ "$INDEX_CHANGED"  -eq 1 ]] && echo "✓ index.html stats updated → $TESTS tests"

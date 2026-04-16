#!/usr/bin/env bash
# E2E verification: checks that OTel Collector received Traces, Metrics, and Logs
#
# Usage: bash test/e2e/verify.sh
#
# Expects: test/e2e/output/{traces,metrics,logs}.json to exist
#   (populated by OTel Collector file exporter after running scenario.exs)

set -euo pipefail

OUTPUT_DIR="test/e2e/output"
PASS=0
FAIL=0

check() {
  local label="$1"
  local condition="$2"

  if eval "$condition" > /dev/null 2>&1; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== E2E Verification ==="

# --- Traces ---
echo ""
echo "--- Traces ---"

TRACES_FILE="$OUTPUT_DIR/traces.json"

check "traces.json exists" "[ -s '$TRACES_FILE' ]"
check "contains resourceSpans" "jq -e '.resourceSpans' '$TRACES_FILE'"
check "contains e2e-parent-span" "jq -e '.. | .name? // empty | select(. == \"e2e-parent-span\")' '$TRACES_FILE'"
check "contains e2e-child-span" "jq -e '.. | .name? // empty | select(. == \"e2e-child-span\")' '$TRACES_FILE'"
check "contains e2e-logged-span" "jq -e '.. | .name? // empty | select(. == \"e2e-logged-span\")' '$TRACES_FILE'"
check "child span has http.method attribute" "jq -e '.. | .attributes? // empty | .[] | select(.key == \"http.method\")' '$TRACES_FILE'"
check "child span has processing_complete event" "jq -e '.. | .events? // empty | .[] | select(.name == \"processing_complete\")' '$TRACES_FILE'"
check "scope name is e2e_test" "jq -e '.. | .scope? // empty | select(.name == \"e2e_test\")' '$TRACES_FILE'"

# --- Metrics ---
echo ""
echo "--- Metrics ---"

METRICS_FILE="$OUTPUT_DIR/metrics.json"

check "metrics.json exists" "[ -s '$METRICS_FILE' ]"
check "contains resourceMetrics" "jq -e '.resourceMetrics' '$METRICS_FILE'"
check "contains http.requests metric" "jq -e '.. | .name? // empty | select(. == \"http.requests\")' '$METRICS_FILE'"
check "contains http.duration metric" "jq -e '.. | .name? // empty | select(. == \"http.duration\")' '$METRICS_FILE'"
check "contains system.cpu metric" "jq -e '.. | .name? // empty | select(. == \"system.cpu\")' '$METRICS_FILE'"
check "http.requests is Sum type" "jq -e '[.. | objects | select(.name == \"http.requests\")] | .[0].sum' '$METRICS_FILE'"
check "http.duration is Histogram type" "jq -e '[.. | objects | select(.name == \"http.duration\")] | .[0].histogram' '$METRICS_FILE'"
check "system.cpu is Gauge type" "jq -e '[.. | objects | select(.name == \"system.cpu\")] | .[0].gauge' '$METRICS_FILE'"

# --- Logs ---
echo ""
echo "--- Logs ---"

LOGS_FILE="$OUTPUT_DIR/logs.json"

check "logs.json exists" "[ -s '$LOGS_FILE' ]"
check "contains resourceLogs" "jq -e '.resourceLogs' '$LOGS_FILE'"
check "contains INFO log" "jq -e '.. | .severityText? // empty | select(. == \"INFO\")' '$LOGS_FILE'"
check "contains ERROR log" "jq -e '.. | .severityText? // empty | select(. == \"ERROR\")' '$LOGS_FILE'"
check "contains E2E test started body" "jq -e '.. | .body? // empty | .stringValue? // empty | select(. == \"E2E test started\")' '$LOGS_FILE'"
check "contains log with trace context (non-empty traceId)" "jq -e '.. | select(.body?.stringValue == \"Log with trace context\") | select(.traceId != \"\" and .traceId != \"AAAAAAAAAAAAAAAAAAAAAA==\")' '$LOGS_FILE'"
check "scope name is e2e_test" "jq -e '.resourceLogs[].scopeLogs[] | select(.scope.name == \"e2e_test\")' '$LOGS_FILE'"

# --- Summary ---
echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  $PASS/$TOTAL passed"

if [ "$FAIL" -gt 0 ]; then
  echo "  ✗ E2E VERIFICATION FAILED"
  exit 1
else
  echo "  ✓ ALL CHECKS PASSED"
  exit 0
fi

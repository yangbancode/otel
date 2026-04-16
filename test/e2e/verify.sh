#!/usr/bin/env bash
# E2E verification: checks OTel Collector received all signals from the scenario
#
# Usage: bash test/e2e/verify.sh

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

# ---------------------------------------------------------------
# TRACES
# ---------------------------------------------------------------
echo ""
echo "--- Traces ---"

T="$OUTPUT_DIR/traces.json"

check "traces.json exists and non-empty" "[ -s '$T' ]"
check "contains resourceSpans" "jq -e '.resourceSpans' '$T'"

# Scenario 1: successful order (4-level depth)
check "gateway span: HTTP POST /api/orders" \
  "jq -e '.. | .name? // empty | select(. == \"HTTP POST /api/orders\")' '$T'"
check "order span: OrderService.create_order" \
  "jq -e '.. | .name? // empty | select(. == \"OrderService.create_order\")' '$T'"
check "payment span: PaymentService.charge" \
  "jq -e '.. | .name? // empty | select(. == \"PaymentService.charge\")' '$T'"
check "db span: DB INSERT payments" \
  "jq -e '.. | .name? // empty | select(. == \"DB INSERT payments\")' '$T'"
check "db span: DB INSERT orders" \
  "jq -e '.. | .name? // empty | select(. == \"DB INSERT orders\")' '$T'"

# Span attributes
check "gateway span has http.method=POST" \
  "jq -e '.. | .attributes? // empty | .[] | select(.key == \"http.method\" and .value.stringValue == \"POST\")' '$T'"
check "db span has db.system=postgresql" \
  "jq -e '.. | .attributes? // empty | .[] | select(.key == \"db.system\" and .value.stringValue == \"postgresql\")' '$T'"
check "order span has order.id=ORD-12345" \
  "jq -e '.. | .attributes? // empty | .[] | select(.key == \"order.id\" and .value.stringValue == \"ORD-12345\")' '$T'"

# Events
check "order.validated event exists" \
  "jq -e '.. | .events? // empty | .[] | select(.name == \"order.validated\")' '$T'"
check "payment.authorized event exists" \
  "jq -e '.. | .events? // empty | .[] | select(.name == \"payment.authorized\")' '$T'"

# Scenario 2: failed order (error status)
check "failed order: status ERROR on payment span" \
  "jq -e '.. | .status? // empty | select(.code == 2)' '$T'"
check "failed order: exception event recorded" \
  "jq -e '.. | .events? // empty | .[] | select(.name == \"exception\")' '$T'"
check "failed order: ORD-99999 attribute" \
  "jq -e '.. | .attributes? // empty | .[] | select(.key == \"order.id\" and .value.stringValue == \"ORD-99999\")' '$T'"

# Scenario 3: health check span
check "health check span: HTTP GET /api/health" \
  "jq -e '.. | .name? // empty | select(. == \"HTTP GET /api/health\")' '$T'"

# Multi-scope
check "scope: gateway" \
  "jq -e '.. | .scope? // empty | select(.name == \"gateway\")' '$T'"
check "scope: order-service" \
  "jq -e '.. | .scope? // empty | select(.name == \"order-service\")' '$T'"
check "scope: payment-service" \
  "jq -e '.. | .scope? // empty | select(.name == \"payment-service\")' '$T'"
check "scope: db-client" \
  "jq -e '.. | .scope? // empty | select(.name == \"db-client\")' '$T'"

# ---------------------------------------------------------------
# METRICS
# ---------------------------------------------------------------
echo ""
echo "--- Metrics ---"

M="$OUTPUT_DIR/metrics.json"

check "metrics.json exists and non-empty" "[ -s '$M' ]"
check "contains resourceMetrics" "jq -e '.resourceMetrics' '$M'"

# Instrument names
check "http.server.requests counter" \
  "jq -e '.. | .name? // empty | select(. == \"http.server.requests\")' '$M'"
check "http.server.duration histogram" \
  "jq -e '.. | .name? // empty | select(. == \"http.server.duration\")' '$M'"
check "orders.created counter" \
  "jq -e '.. | .name? // empty | select(. == \"orders.created\")' '$M'"
check "orders.failed counter" \
  "jq -e '.. | .name? // empty | select(. == \"orders.failed\")' '$M'"
check "payment.processing_time histogram" \
  "jq -e '.. | .name? // empty | select(. == \"payment.processing_time\")' '$M'"
check "payment.gateway.balance gauge" \
  "jq -e '.. | .name? // empty | select(. == \"payment.gateway.balance\")' '$M'"

# Type verification
check "http.server.requests is Sum" \
  "jq -e '[.. | objects | select(.name == \"http.server.requests\")] | .[0].sum' '$M'"
check "http.server.duration is Histogram" \
  "jq -e '[.. | objects | select(.name == \"http.server.duration\")] | .[0].histogram' '$M'"
check "payment.gateway.balance is Gauge" \
  "jq -e '[.. | objects | select(.name == \"payment.gateway.balance\")] | .[0].gauge' '$M'"

# Multi-scope
check "metrics scope: gateway" \
  "jq -e '.. | .scope? // empty | select(.name == \"gateway\")' '$M'"
check "metrics scope: order-service" \
  "jq -e '.. | .scope? // empty | select(.name == \"order-service\")' '$M'"
check "metrics scope: payment-service" \
  "jq -e '.. | .scope? // empty | select(.name == \"payment-service\")' '$M'"

# ---------------------------------------------------------------
# LOGS
# ---------------------------------------------------------------
echo ""
echo "--- Logs ---"

L="$OUTPUT_DIR/logs.json"

check "logs.json exists and non-empty" "[ -s '$L' ]"
check "contains resourceLogs" "jq -e '.resourceLogs' '$L'"

# Severity levels
check "contains INFO log" \
  "jq -e '.. | .severityText? // empty | select(. == \"INFO\")' '$L'"
check "contains ERROR log" \
  "jq -e '.. | .severityText? // empty | select(. == \"ERROR\")' '$L'"
check "contains DEBUG log" \
  "jq -e '.. | .severityText? // empty | select(. == \"DEBUG\")' '$L'"

# Log bodies
check "log: Incoming order request" \
  "jq -e '.. | .body? // empty | .stringValue? // empty | select(. == \"Incoming order request\")' '$L'"
check "log: Payment declined for order ORD-99999" \
  "jq -e '.. | .body? // empty | .stringValue? // empty | select(contains(\"Payment declined\"))' '$L'"
check "log: Executing INSERT INTO payments" \
  "jq -e '.. | .body? // empty | .stringValue? // empty | select(contains(\"INSERT INTO payments\"))' '$L'"

# Trace-log correlation (logs emitted inside spans have traceId)
check "log with trace context has non-empty traceId" \
  "jq -e '[.. | objects | select(.body?.stringValue == \"Incoming order request\")] | .[0] | select(.traceId != \"\" and .traceId != null)' '$L'"

# Error log has exception attributes
check "error log has exception.type attribute" \
  "jq -e '.. | .attributes? // empty | .[] | select(.key == \"exception.type\")' '$L'"

# :logger bridge logs
check ":logger bridge: Health check passed" \
  "jq -e '.. | .body? // empty | .stringValue? // empty | select(contains(\"Health check\"))' '$L'"
check ":logger bridge: Connection pool warning" \
  "jq -e '.. | .body? // empty | .stringValue? // empty | select(contains(\"Connection pool\"))' '$L'"
check ":logger bridge: Failed to connect" \
  "jq -e '.. | .body? // empty | .stringValue? // empty | select(contains(\"Failed to connect\"))' '$L'"

# ---------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------
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

#!/usr/bin/env bash
# E2E test runner: starts collector, runs scenario, verifies output
#
# Usage: bash test/e2e/run.sh

set -euo pipefail

E2E_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$E2E_DIR/../.." && pwd)"

cd "$E2E_DIR"

export DOCKER_UID=$(id -u)
export DOCKER_GID=$(id -g)

echo "[e2e] Stopping any existing Collector..."
docker compose down 2>/dev/null || true

echo "[e2e] Cleaning previous output..."
rm -rf output
mkdir -p output

echo "[e2e] Starting OTel Collector..."
docker compose up -d

echo "[e2e] Waiting for Collector to be ready..."
for i in $(seq 1 30); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4318/v1/traces 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" != "000" ]; then
    echo "[e2e] Collector is ready (HTTP $HTTP_CODE)."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "[e2e] ERROR: Collector did not start within 30 seconds."
    docker compose logs
    docker compose down
    exit 1
  fi
  sleep 1
done

echo "[e2e] Running scenario..."
cd "$PROJECT_DIR"
mix run test/e2e/scenario.exs

echo "[e2e] Waiting for file exporter to flush..."
sleep 3

echo "[e2e] Verifying output..."
bash test/e2e/verify.sh

echo ""
echo "[e2e] Stopping Collector..."
cd "$E2E_DIR"
docker compose down

echo "[e2e] Done."

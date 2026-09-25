#!/usr/bin/env bash
# Build the "before" and "after" images, then compare size, user and CVEs.
# These are the numbers for the "Scan both images and compare" slide.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v trivy >/dev/null || { echo "Install Trivy first: brew install trivy"; exit 1; }

echo "Building orders-api:before and orders-api:after ..."
docker build -q -f insecure-examples/Dockerfile.before -t orders-api:before . >/dev/null
docker build -q -t orders-api:after . >/dev/null

printf '\n%-8s %-10s %-10s %-6s %-8s\n' IMAGE SIZE "RUNS AS" HIGH CRITICAL
for tag in before after; do
  ref="orders-api:$tag"
  size=$(docker image ls "$ref" --format '{{.Size}}' | head -1)
  user=$(docker image inspect -f '{{.Config.User}}' "$ref")
  json=$(trivy image --quiet --scanners vuln --severity HIGH,CRITICAL --format json "$ref")
  high=$( (grep -o '"Severity": *"HIGH"' <<<"$json" || true) | wc -l | tr -d ' ')
  crit=$( (grep -o '"Severity": *"CRITICAL"' <<<"$json" || true) | wc -l | tr -d ' ')
  printf '%-8s %-10s %-10s %-6s %-8s\n' "$tag" "$size" "${user:-root}" "$high" "$crit"
done

echo
echo "Details: trivy image --severity HIGH,CRITICAL orders-api:before"
echo "The secret baked into the before image: docker history --no-trunc orders-api:before | grep API_KEY"

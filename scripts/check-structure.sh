#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  docker-compose.yml
  .env.example
  README.md
  loki/local-config.yaml
  otel/otel-collector-config.yaml
  jaeger/config.yaml
  grafana/provisioning/datasources/datasources.yaml
  grafana/provisioning/dashboards/dashboards.yaml
  deploy/ansible/playbooks/site.yml
  deploy/opentofu/proxmox/main.tf
  docs/windows-wsl-ansible.md
  docs/daily-deployment.md
  docs/linux-deployment.md
  docs/cloudflare-tunnel.md
  docs/validation-report.md
  deploy/ansible/inventory/hosts.ini.example
  CONTRIBUTING.md
  LICENSE
)

for item in "${required[@]}"; do
  test -f "$ROOT/$item" || { echo "Missing: $item" >&2; exit 1; }
done

grep -q 'zabbix/zabbix-server-pgsql:7.4.14-alpine' "$ROOT/docker-compose.yml"
grep -q 'grafana/grafana:13.1.4' "$ROOT/.env.example"
grep -q 'GRAFANA_ZABBIX_PLUGIN_VERSION=6.6.0' "$ROOT/.env.example"
grep -q 'alpine:3.22.1' "$ROOT/.env.example"
grep -q 'grafana/loki:3.7.6' "$ROOT/.env.example"
grep -q 'otel/opentelemetry-collector-contrib:0.157.0' "$ROOT/.env.example"
grep -q 'jaegertracing/jaeger:2.15.0' "$ROOT/.env.example"

echo "Structure checks passed."

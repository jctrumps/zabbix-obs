# Project guidance

## Purpose

Build and operate a small, reproducible observability platform with Zabbix as the authoritative infrastructure monitoring and alerting system.

## Design rules

1. Do not add a component when an existing component already owns the responsibility.
2. Zabbix owns infrastructure health and alerting.
3. Loki owns centralized logs.
4. Jaeger owns distributed traces.
5. OpenTelemetry Collector owns telemetry transport/routing.
6. Grafana owns dashboards and visualization, not a second alerting engine by default.
7. PostgreSQL is application storage for Zabbix, not an observability feature.
8. Avoid `latest` image tags in the committed `.env.example`.
9. Keep secrets out of Git.
10. Prefer reproducible deployment through Ansible and OpenTofu.

## Change discipline

- Update `docs/` when architecture or responsibilities change.
- Update `.env.example` when new configuration is introduced.
- Keep health checks and persistent volumes explicit.
- Validate Compose syntax before committing.

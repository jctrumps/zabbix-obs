# Project status

## Initial scaffold

Status: baseline security, deployment, runtime, and recovery review completed. The validation results below describe tests using placeholder credentials and temporary volumes, with test resources removed afterward.

Included:

- Zabbix 7.4 baseline with PostgreSQL
- Grafana 13.1.4
- Loki 3.7.6
- OpenTelemetry Collector Contrib 0.157.0
- Jaeger 1.76.0
- Docker Compose
- Ansible deployment skeleton
- OpenTofu Proxmox provisioning skeleton
- architecture, deployment, monitoring and alerting documentation
- Windows 10/11 deployment, security review, and backup/restore documentation
- loopback-only published-port defaults and isolated Compose networks

## Completed validation

Static and deployment verification completed:

- all pinned container images pulled successfully
- Compose configuration and repository structure checks passed
- OpenTofu formatting and validation passed with provider 0.111.1
- Ansible inventory and playbook syntax validation passed under WSL 2
- Ansible secret assertions reject placeholder, short, missing, and unsafe-format values
- OpenTofu's configured Proxmox disk size is applied to the VM resource

Runtime verification completed from clean volumes:

- PostgreSQL, Zabbix server, Zabbix web, Grafana, and Jaeger health checks passed
- Loki, OpenTelemetry Collector, and Jaeger internal readiness endpoints passed
- host ports bound to `127.0.0.1`; Loki was confirmed not published
- OpenTelemetry Collector and Loki configuration files validated with their pinned images
- Zabbix server `nc` and web/Grafana `wget` health-check utilities confirmed present
- Jaeger named-volume permission failure found and fixed with `jaeger-init`
- deprecated Grafana plugin syntax found and fixed
- Zabbix plugin 6.6.0 installation confirmed
- Grafana alerting disabled; optional unpinned app downloads disabled
- Grafana provisioning startup errors removed
- Grafana Loki and Jaeger data-source health checks passed
- synthetic OTLP logs and traces were delivered and queried successfully
- deprecated OpenTelemetry exporter aliases were removed

Recovery verification completed:

- PostgreSQL custom-format dump was created and validated with `pg_restore --list`
- Grafana, Loki, and Jaeger named volumes were archived with SHA-256 checksums
- PostgreSQL and all three named volumes were restored into clean storage
- restored Zabbix database state, Grafana connectivity, Loki logs, and Jaeger traces were verified
- new logs and traces were accepted after restoration
- restored services had no restart loops, migration failures, permission failures, or corruption indicators
- Loki's brief startup `503` and one-time empty-ring message were confirmed as transient initialization behavior
- temporary runtime containers, networks, volumes, and backup artifacts were removed after testing

## Production work

1. Place the project in a Git repository and review the initial revision.
2. Deploy with real independent secrets, never the `.env.example` placeholders.
3. Complete first-login Zabbix setup and create named least-privilege users.
4. Configure a dedicated Grafana Zabbix read-only user/API token.
5. Configure and test real Zabbix actions, media types, and notification recovery.
6. Add the first Linux VM with encrypted Zabbix Agent 2 transport.
7. Add the first Proxmox host.
8. Establish encrypted off-host backups, retention, and scheduled restore exercises.
9. Migrate from end-of-life Jaeger 1.x before production use.

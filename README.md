# zabbix-obs

A small, production-oriented observability platform centered on **Zabbix** for infrastructure monitoring and alerting, with **Loki** for logs, **OpenTelemetry Collector + Jaeger** for traces/telemetry transport, and **Grafana** as the visualization layer.

This project intentionally avoids overlapping monitoring products.

## Architecture

```text
                         +----------------------+
                         |       Grafana        |
                         | Visualization layer  |
                         +----------+-----------+
                                    |
                  +-----------------+-----------------+
                  |                 |                 |
                  v                 v                 v
            +-----------+     +-----------+     +-----------+
            |  Zabbix   |     |   Loki    |     |  Jaeger   |
            | Infra +   |     |   Logs    |     |  Traces   |
            | Alerting  |     |           |     |           |
            +-----+-----+     +-----^-----+     +-----^-----+
                  |                  |                 |
        +---------+---------+        |        +--------+--------+
        |                   |        |        |                 |
        v                   v        |        v                 |
  Proxmox / Linux      Windows /     |   OpenTelemetry        |
  / Network / DBs      Services      |      Collector          |
                                     |        |                 |
                                     +--------+-----------------+
```

### Service responsibilities

| Service | Responsibility |
|---|---|
| Zabbix | Infrastructure health, metrics, discovery, service checks, alerting |
| PostgreSQL | Zabbix database |
| Grafana | Dashboards and cross-source visualization |
| Loki | Centralized log storage/search |
| OpenTelemetry Collector | Vendor-neutral telemetry ingest/routing |
| Jaeger | Distributed trace storage/query |

Not included intentionally: Prometheus, Node Exporter, Beszel, Uptime Kuma, Promtail, ClickHouse, and a separate reverse proxy.

## Initial sizing

Recommended starting VM:

- 4 vCPU
- 8 GB RAM
- 100 GB SSD
- Debian 13
- Docker Engine + Compose v2

Scale based on actual monitoring cardinality and retention rather than pre-sizing for an arbitrary large deployment.

## Quick start

```bash
cp .env.example .env
# Edit .env and replace all three CHANGE_ME values with independent secrets.
docker compose config --quiet
docker compose pull
docker compose up -d
```

Endpoints:

- Zabbix: <http://localhost:8080>
- Grafana: <http://localhost:3000>
- Jaeger: <http://localhost:16686>
- OTLP gRPC: `localhost:4317`
- OTLP HTTP: `localhost:4318`
- Zabbix server: `localhost:10051`

Default Zabbix frontend credentials are the upstream defaults on a fresh database; change them immediately during first login. Grafana credentials come from `.env`.

All published ports bind to `127.0.0.1` by default. Loki is internal-only. Read the deployment and security guides before changing bind addresses.

## Persistent data

Docker named volumes are used for all persistent state:

- `zabbix-obs-postgres`
- `zabbix-obs-grafana`
- `zabbix-obs-loki`
- `zabbix-obs-jaeger`

Back these up before upgrades or infrastructure changes. See `docs/backup-restore.md`; copying the repository does not back up named volumes.

## Zabbix monitoring model

Zabbix is authoritative for infrastructure health. Recommended host groups:

- Proxmox
- Linux Servers
- Windows Servers
- Databases
- Web Servers
- Applications
- Network
- Websites

Recommended first templates:

- Linux by Zabbix agent
- Windows by Zabbix agent
- Apache by Zabbix agent
- PostgreSQL by Zabbix agent 2
- HTTP/HTTPS web scenarios
- SNMP network devices

Application-specific templates should be added only when there is a clear monitoring requirement.

## Logs and traces

Applications should send telemetry to the OpenTelemetry Collector using OTLP. The collector routes:

- logs -> Loki via OTLP/HTTP
- traces -> Jaeger via OTLP

Zabbix remains independent of this pipeline so an application telemetry outage does not disable infrastructure monitoring.

## Security stance

This Compose project is intended for internal deployment. Do not publish Zabbix, Grafana, Jaeger, or OTLP ports directly to the public Internet. Loki has no host port by default.

For remote administrative access, use an authenticated HTTPS reverse proxy with existing private networking/Zero Trust controls. Zabbix and Grafana otherwise serve HTTP, Jaeger has no login, and the OTLP receivers have no authentication or TLS in this baseline. If an edge is required, add it as an explicit environment-specific component rather than making it part of the core observability stack.

## Deployment

The repository uses the following deployment model:

- Docker Compose for local validation
- Ansible for VM convergence
- OpenTofu for infrastructure provisioning
- separate `dev`, `staging`, and `prod` inventories

See:

- `docs/architecture.md`
- `docs/deployment.md`
- `docs/windows-deployment.md`
- `docs/security.md`
- `docs/publication.md`
- `docs/backup-restore.md`
- `docs/monitoring-plan.md`
- `docs/alerting.md`
- `deploy/ansible/`
- `deploy/opentofu/proxmox/`

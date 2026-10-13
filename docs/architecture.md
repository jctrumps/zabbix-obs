# Architecture

## Core design

Primary operator path: Windows CMD + native OpenTofu creates a dedicated
Proxmox VM; Windows CMD enters `deploy/ansible` then starts WSL Ubuntu;
Ansible over SSH configures the guest and deploys Docker Compose. Debian 13
amd64 is the default; Ubuntu 24.04 amd64 is also supported. Start with
4 vCPU, 8 GiB RAM, and a 100 GiB disk. The existing `deploy/` layout is
retained so deployment assets have one home.

`zabbix-obs` deliberately separates infrastructure monitoring from logs and distributed tracing.

### Zabbix

Authoritative system for:

- host availability
- CPU, memory, swap, disk and network
- service/process state
- SNMP and network-device monitoring
- HTTP/HTTPS checks
- SSL certificate expiration
- application/service health checks
- thresholds and notifications

### Loki

Central log store. It is not responsible for infrastructure alerting.

### OpenTelemetry Collector

Receives OTLP logs and traces and routes them to their storage backends. It is a transport layer, not a second monitoring UI.

### Jaeger

Jaeger 2 trace store and trace UI for request-level investigation. Badger
persists in `zabbix-obs-jaeger-v2` with 48-hour trace retention. This is
deliberately distinct from the old Jaeger 1 volume; see [operations](operations.md).

### Grafana

Visualization layer. It reads Zabbix, Loki and Jaeger data so operators can move from infrastructure problem -> logs -> trace from one UI when useful.

## Data flow

```text
Hosts / Services
      |
      +--------------------> Zabbix Agent / SNMP / HTTP -> Zabbix
      |
      +--------------------> OTLP -> OpenTelemetry Collector
                                         |
                                   +-----+-----+
                                   |           |
                                  Logs       Traces
                                   |           |
                                  Loki       Jaeger
                                   \           /
                                    \         /
                                     -> Grafana
```

## Network boundaries

Compose separates the stack into three bridge networks:

- `database`: internal network for PostgreSQL, Zabbix server, and Zabbix web
- `visualization`: Zabbix web, Grafana, Loki, Jaeger, and Zabbix server health checks
- `telemetry`: OpenTelemetry Collector, Loki, Jaeger, and Zabbix server health checks

PostgreSQL and Loki have no host-published ports. Administrative and ingestion ports bind to host loopback unless an operator explicitly changes the relevant bind-address variable. Compose network separation reduces accidental reachability but is not a replacement for host firewalling, TLS, authentication, or a dedicated security boundary.

The short-lived `jaeger-init` service only sets ownership on the Jaeger named volume, then exits. It is required because Jaeger runs as non-root UID 10001 and Docker creates a new named volume owned by root.

The short-lived `grafana-init` service installs the exact configured Zabbix plugin version into the Grafana volume, then exits. It skips installation when that exact version is present and replaces the plugin when the configured version changes. Grafana's own automatic preinstall feature is disabled so it cannot download unrequested latest-version apps at startup.

## Availability and scale

The baseline is a single-node design. PostgreSQL, Loki filesystem storage, and Jaeger Badger storage are local failure domains. Single-process Jaeger with Badger is appropriate only for light trace volume. Requirements for high availability, larger retention, or horizontal scale require a separately designed PostgreSQL HA/backup strategy and supported distributed Loki/Jaeger storage.

PostgreSQL, Zabbix and Grafana have Compose health checks. Loki, the Collector
and Jaeger expose internal readiness endpoints but their minimal images do not
provide a general HTTP probe tool. Ansible polls those endpoints from the existing
Zabbix container; operations documentation provides the same checks. No extra
monitoring service is added. Cloudflare routing is optional and manually managed.

## Intentional exclusions

- Prometheus: not installed initially; Zabbix covers infrastructure metrics.
- Node Exporter: not installed; install Zabbix Agent 2 on monitored Linux hosts.
- Beszel: replaced by Zabbix.
- Uptime Kuma: replaced by Zabbix web/availability monitoring.
- Promtail: replaced by OpenTelemetry Collector for the new telemetry path.
- ClickHouse: no defined workload yet.
- Caddy: edge access is intentionally outside the core stack.

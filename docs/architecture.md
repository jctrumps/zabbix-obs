# Architecture

## Core design

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

Trace store and trace UI for request-level investigation.

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

The baseline is a single-node design. PostgreSQL, Loki filesystem storage, and Jaeger Badger storage are local failure domains. Jaeger all-in-one with Badger is appropriate only for light trace volume. Requirements for high availability, larger retention, or horizontal scale require a separately designed PostgreSQL HA/backup strategy and supported distributed Loki/Jaeger storage.

## Intentional exclusions

- Prometheus: not installed initially; Zabbix covers infrastructure metrics.
- Node Exporter: not installed; install Zabbix Agent 2 on monitored Linux hosts.
- Beszel: replaced by Zabbix.
- Uptime Kuma: replaced by Zabbix web/availability monitoring.
- Promtail: replaced by OpenTelemetry Collector for the new telemetry path.
- ClickHouse: no defined workload yet.
- Caddy: edge access is intentionally outside the core stack.

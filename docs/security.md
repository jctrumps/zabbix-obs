# Security review and hardening

## Trust boundaries

This stack handles infrastructure inventory, user accounts, logs, and traces. Logs and traces can contain customer identifiers, URLs, query text, tokens, headers, or application payloads. Treat all stored telemetry as sensitive operational data.

The Docker host, Docker operators, root/Administrator, the Ansible control account, and anyone able to read `.env` can access deployment secrets and all persisted data. Grafana and Zabbix users must not receive host or Docker access.

## Controls included

- Published ports bind to `127.0.0.1` by default.
- PostgreSQL is not published and resides on an internal database network.
- Loki is not published on the host.
- Visualization, telemetry, and database traffic use separate Compose networks.
- Containers use `no-new-privileges` and bounded local log files.
- PostgreSQL host authentication is initialized with SCRAM-SHA-256.
- Grafana self-registration, Gravatar, analytics reporting, and update checks are disabled.
- Grafana alerting is disabled so Zabbix remains the authoritative alerting engine.
- Grafana's default optional app downloads are disabled; only the pinned Zabbix plugin is preinstalled.
- Grafana requires an independent encryption secret.
- Provisioned Loki and Jaeger data sources are not editable in the UI.
- The collector debug exporter is disabled so telemetry is not copied into Docker logs.
- Ansible rejects placeholder and short deployment secrets.
- Images and the Grafana plugin use version tags rather than `latest`.

These are defense-in-depth controls, not a complete production security boundary.

## Risk register

| Severity | Risk | Current mitigation | Required production action |
|---|---|---|---|
| High | Zabbix and Grafana serve HTTP, so network logins lack transport encryption | Loopback-only default | Put all remote UI access behind an authenticated HTTPS edge |
| High | OTLP has no authentication or TLS and can accept sensitive or abusive payloads | Loopback-only default and isolated network | Use TLS/mTLS or an authenticated gateway; restrict sender networks |
| High | Jaeger UI/API has no user authentication | Loopback-only default | Restrict to administrators behind the authenticated edge |
| High | Single host and single PostgreSQL instance are a monitoring and alerting failure domain | Persistent volumes and restart policy | Maintain off-host backups; use HA architecture if the business requirement demands it |
| High | Single-node Jaeger 2/Badger has a local storage failure domain | Pinned version, persistent volume, 48-hour retention and private exposure | Back up traces; use supported distributed storage before scaling |
| Medium | Secrets are passed through container environment and are visible to Docker administrators | `.env` excluded from Git and mode `0600` under Ansible | Limit Docker access; use a secrets manager/file-based secrets if threat model requires it |
| Medium | Version tags are mutable and no vulnerability scan is automated | Explicit tags | Resolve and record digests, generate an SBOM, and scan images in promotion workflow |
| Medium | Loki and Jaeger are single-node local stores; disk exhaustion can stop services | Loki 30-day retention and log rotation | Set capacity alerts, test retention, and define trace retention/storage strategy |
| Medium | Telemetry may contain credentials, personal data, or regulated data | Debug duplication removed | Apply SDK redaction/allowlists and collector filters before ingestion |
| Medium | Backup procedures are manual and backups may contain all sensitive data | Documented backup/restore process | Automate encrypted off-host backups and test restoration on schedule |
| Medium | Docker socket access is effectively host-administrative | No socket is mounted into containers | Restrict Docker Desktop/daemon access to designated operators |
| Low | Runtime image/plugin downloads depend on external registries | Versions are pinned | Mirror approved artifacts and pre-stage them in restricted environments |
| Low | The Grafana Zabbix integration is a third-party plugin loaded into Grafana | Exact plugin version is pinned | Review release provenance and scan/approve the plugin before promotion |
| Low | No resource limits are imposed, so one service can pressure the host | Collector memory limiter and starting capacity guidance | Measure the workload and add tested service limits rather than arbitrary caps |

## Production checklist

- Use a dedicated, patched Linux VM with disk encryption where required.
- Keep the host and management interfaces on private networks.
- Use default-deny inbound firewall policy and explicit source ranges.
- Require HTTPS for every remote UI session.
- Use named accounts, least-privilege roles, short-lived API tokens, and MFA where supported by the selected identity integration.
- Disable or tightly control shared bootstrap and local administrator accounts.
- Encrypt Zabbix agent/proxy traffic with PSK or certificates.
- Encrypt and authenticate OTLP when traffic leaves a trusted host/network.
- Redact secrets and sensitive attributes in applications before export.
- Define log and trace retention from legal, privacy, and operational requirements.
- Send Zabbix notifications through a tested channel independent of Grafana.
- Alert on filesystem use, certificate expiry, failed backups, Zabbix queue depth, unsupported items, and container restarts.
- Store Ansible secrets in Vault or an external secrets system.
- Store OpenTofu state in a protected backend with locking and backup.
- Scan pinned images and plugin artifacts before each promotion.
- Test backups and incident runbooks at least quarterly.
- Document owners, on-call contacts, maintenance windows, recovery objectives, and data classification.

## Out of scope for this baseline

The project does not provide an identity provider, certificate authority, reverse proxy, VPN, SIEM, immutable archive, highly available database, or distributed Loki/Jaeger storage. Add or integrate those only when a concrete requirement exists and document the resulting trust boundaries.

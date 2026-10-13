# Operations

Routine application convergence uses [daily deployment](daily-deployment.md).
Commands in this guide run on the **REMOTE VM** after verified SSH login.
Use `sudo` because Ansible renders `.env` root-only; Docker access is root-equivalent.

## Status, health and logs

```bash
cd /opt/zabbix-obs
sudo docker version
sudo docker compose version
sudo docker compose config --quiet
sudo docker compose ps --all
curl -fsS http://127.0.0.1:8080/ -o /dev/null
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:16686/ -o /dev/null
sudo docker compose exec -T zabbix-server wget -qO- http://loki:3100/ready
sudo docker compose exec -T zabbix-server wget -qO- http://otel-collector:13133/
sudo docker compose exec -T zabbix-server wget -qO- http://jaeger:13133/status
sudo docker compose logs --since 30m --tail 200
sudo docker stats --no-stream
df -h
sudo docker volume inspect zabbix-obs-postgres zabbix-obs-grafana zabbix-obs-loki zabbix-obs-jaeger-v2
sudo docker inspect --format '{{json .HostConfig.PortBindings}}' zabbix-obs-web zabbix-obs-grafana zabbix-obs-jaeger zabbix-obs-otel zabbix-obs-server
```

Expected: init jobs exit 0; long-running services stay running; configured
health checks pass; internal endpoints return HTTP 200. Loki may return 503
briefly while its ring initializes. Persistent errors need log investigation.
Adjust project/port names for local overrides. Host bindings must match the
intended exposure. Check actual mounts with `sudo docker inspect --format
'{{json .Mounts}}' zabbix-obs-postgres` (repeat for other stateful containers).

Do not publish rendered config, full container inspect output, logs or telemetry
without reviewing for secrets. `config --quiet` avoids printing credentials.

## First-run acceptance

Use the SSH forwarding commands in the Windows or Linux guide for browser
access. In the **ZABBIX/GRAFANA WEB UI**:

1. Change Zabbix `Admin` / `zabbix` bootstrap credentials, create named accounts.
2. Log in to Grafana using the Vault password; follow [Grafana integration](grafana.md).
3. Ensure the Zabbix server is reported running. Register a test monitored host,
   configure agent PSK/certificate encryption and verify data arrives.
4. Configure Zabbix actions/media and verify a test alert and recovery.
5. Send a test log and trace through the Collector from a controlled application,
   then query them in Loki/Jaeger and verify Grafana data-source tests.
6. Test [backup/restore](backup-restore.md), then optional [external access](cloudflare-tunnel.md).

## Configuration and upgrades

**WSL / UBUNTU BASH**, `deploy/ansible`: edit local `inventory/vars.yml` for
non-secret changes, or `ansible-vault edit "$HOME/.config/zabbix-obs/vault.yml"`
for secrets. Use daily deployment commands. Managed files under `/opt/zabbix-obs`
are overwritten on rerun. The role recreates containers when managed config
files change so bind-mounted configuration is reloaded.

Before changing versions, read upstream release/migration notes and take a
verified backup. Update the image pins consistently in `.env.example`, Compose,
Ansible's environment template and source checks; alternatively use a local image
override for a staging evaluation. Tags are deliberate versions but not immutable
digests; record resolved digests before production promotion. Test one component
family at a time on an isolated clone, including alert/ingestion and recovery.

Set `obs_upgrade_os: true` and/or `obs_upgrade_docker: true` locally during an
approved maintenance window, deploy, then reset to false. Ansible does not reboot.
On the **REMOTE VM**, inspect `/var/run/reboot-required` if present, coordinate
downtime, and use `sudo reboot` only when ready. Verify service startup afterward.

Password changes need application-aware rotation: changing an existing
PostgreSQL environment password does not alter its database role, and Grafana's
admin environment password initializes only a new database. Coordinate database
role/password and Zabbix configuration changes. Preserve the Grafana secret key
unless following Grafana's supported encryption-key rotation process.

## Jaeger 1 to 2 transition

This release replaces archived `jaegertracing/all-in-one:1.76.0` with
`jaegertracing/jaeger:2.15.0` and an explicit YAML configuration. It uses a **new**
`zabbix-obs-jaeger-v2` volume. The old `zabbix-obs-jaeger` volume is preserved,
but historical v1 traces are not automatically imported into v2. New deployments
need no migration. Existing deployments should:

1. Back up all data and retain the old source/config/image digest.
2. Stop ingestion and archive the old trace volume before deploying the change.
3. Validate v2 on an isolated deployment; test fresh trace ingestion/query.
4. If historical traces must remain queryable, retain an isolated legacy viewer
   temporarily or develop/test an explicit export/reingestion procedure. Do not
   point v2 at the old Badger database without verified compatibility.
5. Resume senders only after validation. Old traces remain in the untouched old
   volume; retire that volume separately when retention policy permits.

Jaeger stores 48 hours of spans by default in `jaeger/config.yaml`. Badger is
single-node storage and is not appropriate for HA or large trace workloads.

## Rollback and stop

A prior image alone may not understand an upgraded database schema. Stop writers,
restore matching backups to an isolated instance with the prior repository
revision and secrets, verify it, then cut over. See [backup/restore](backup-restore.md).
For Jaeger, the prior revision uses its distinct v1 volume; do not mix versions.

**REMOTE VM**, retain data while stopping/removing containers:

```bash
cd /opt/zabbix-obs
sudo docker compose stop
# Restart later:
sudo docker compose start
# Or remove containers/networks while retaining named volumes:
sudo docker compose down
```

`docker compose down -v` deletes named volumes. Use it only for intentional
decommission after verified backup. VM destruction also deletes guest data;
see [OpenTofu lifecycle](opentofu.md).

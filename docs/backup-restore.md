# Backup and restore

A recoverable set includes a PostgreSQL logical dump, Grafana/Loki/Jaeger
volumes, the matching repository revision/image digests, and encrypted secrets
(especially `GRAFANA_SECRET_KEY`). Repository copies do not back up named volumes.
Use encrypted off-host storage, retention, backup monitoring and isolated restore
exercises. Backup commands below deliberately stop writers for consistency;
schedule downtime and pause/retry telemetry senders.

## Backup — REMOTE VM Bash

SSH to the guest; become root so `.env` and backup files remain private:

```bash
sudo -i
cd /opt/zabbix-obs
umask 077
BACKUP="/var/backups/zabbix-obs/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$BACKUP"
docker compose config --quiet
docker compose stop zabbix-server zabbix-web otel-collector grafana loki jaeger
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$BACKUP/zabbix.dump"
docker compose exec -T postgres pg_restore --list < "$BACKUP/zabbix.dump"
for name in grafana loki jaeger-v2; do
  docker run --rm --network none \
    --mount "type=volume,source=zabbix-obs-$name,target=/source,readonly" \
    --mount "type=bind,source=$BACKUP,target=/backup" \
    alpine:3.22.1 tar -czf "/backup/$name.tgz" -C /source . || break
done
(cd "$BACKUP" && sha256sum zabbix.dump grafana.tgz loki.tgz jaeger-v2.tgz > SHA256SUMS)
docker compose up -d --wait --wait-timeout 300
docker compose ps
exit
```

Use the configured Compose project name if it differs from `zabbix-obs`.
Check every command result; do not treat a partial archive set as a backup.
For volume archives, run `tar -tzf` before transfer. Run the internal readiness
probes in [operations](operations.md) after resuming; Compose alone does not
probe minimal-image telemetry services. If dumping/archiving fails, preserve
diagnostics locally, restore service promptly, fix capacity/permissions and retry.

Keep application secrets in a **separate encrypted** backup using your secrets
manager. Do not place unencrypted `.env` in the data archive. Transfer the data
set using your encrypted backup system and verify its SHA-256 checksums on the
destination. Establish schedules/RPO/RTO appropriate to your monitoring history.

## Restore prerequisites

Use an isolated disposable VM without production senders or notifications.
Deploy the exact matching source/images and original secrets. If Ansible already
started services on the restore target, stop them before restoring. Use **empty
named volumes**; never extract over an existing database. Preserve original
backups. A fresh v2 archive is restored to v2, not a v1 volume.

## Restore — REMOTE VM Bash, isolated target only

Place verified backups under `/var/backups/zabbix-obs/restore` on the target,
then:

```bash
sudo -i
cd /opt/zabbix-obs
BACKUP=/var/backups/zabbix-obs/restore
(cd "$BACKUP" && sha256sum -c SHA256SUMS)
docker compose stop
docker compose up -d postgres
docker compose ps postgres
```

Wait until PostgreSQL is healthy. The following drops/recreates **the target
database** and must never be run against production for a restore exercise:

```bash
docker compose exec -T postgres sh -c 'dropdb -U "$POSTGRES_USER" --if-exists "$POSTGRES_DB" && createdb -U "$POSTGRES_USER" -O "$POSTGRES_USER" "$POSTGRES_DB"'
docker compose exec -T postgres sh -c 'pg_restore --exit-on-error -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges' < "$BACKUP/zabbix.dump"
```

For **fresh empty** non-database target volumes (if Ansible populated them, use
a new isolated project/VM or deliberately remove only those test volumes first):

```bash
for name in grafana loki jaeger-v2; do
  docker volume create "zabbix-obs-$name"
  docker run --rm --network none \
    --mount "type=volume,source=zabbix-obs-$name,target=/target" \
    --mount "type=bind,source=$BACKUP,target=/backup,readonly" \
    alpine:3.22.1 sh -ec \
    'test -z "$(ls -A /target)"; tar -xzf "/backup/$1.tgz" -C /target' sh "$name" || break
done
docker compose up -d --wait --wait-timeout 300
docker compose ps --all
exit
```

If the empty-volume check fails, stop and prepare a genuinely isolated empty
target rather than bypassing the check. If any restore step fails, do not
reconnect users/senders. Check logs and archive integrity.

## Acceptance and rollback

Run [operations health checks](operations.md), log in with restored named users,
verify Zabbix hosts/history/actions and Grafana dashboards/data sources. Query a
known retained Loki log and Jaeger trace, then send new telemetry. Test alert and
recovery delivery to an isolated recipient. Record restore duration and errors.
Only reconnect production senders after validation. Rollback after a schema
upgrade requires the pre-upgrade source, images and compatible backup, not just
changing an image tag. The validation report states which tests were actually run.

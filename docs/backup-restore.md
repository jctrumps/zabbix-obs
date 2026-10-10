# Backup and restore

## Scope

A complete recoverable backup includes:

- a PostgreSQL logical dump for all Zabbix configuration, history, users, and events
- the Grafana volume for users, data-source secrets, plugins, and UI-managed content
- the Loki volume for retained logs
- the Jaeger volume for retained traces
- the repository revision and the corresponding `.env` values or secrets-manager records

The `.env` file contains credentials and the Grafana encryption key. Store it separately in an encrypted secrets backup, not in the same unencrypted archive as application data.

Copying the project directory alone does not back up Docker named volumes.

## Backup requirements

- Write backups outside the repository.
- Encrypt backups at rest and in transit.
- Keep at least one off-host/off-site copy.
- Define retention and recovery objectives.
- Monitor backup success and capacity.
- Test restoration on an isolated host; an untested backup is not a recovery plan.

## PostgreSQL backup

Create a custom-format logical dump. These PowerShell commands avoid binary corruption from shell redirection:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $HOME "zabbix-obs-backups\$stamp"
New-Item -ItemType Directory -Path $backupRoot | Out-Null

docker compose exec -T postgres pg_dump `
    -U zabbix -d zabbix -Fc -f /tmp/zabbix.dump

$postgresId = docker compose ps -q postgres
docker cp "${postgresId}:/tmp/zabbix.dump" (Join-Path $backupRoot 'zabbix.dump')
docker compose exec -T postgres rm -f /tmp/zabbix.dump
```

If `ZABBIX_DB_USER` or `ZABBIX_DB_NAME` differs from the defaults, use the configured values. Verify the dump:

```powershell
Get-Item (Join-Path $backupRoot 'zabbix.dump')
docker run --rm --mount "type=bind,source=$backupRoot,target=/backup,readonly" `
    postgres:17.11-alpine3.24 pg_restore --list /backup/zabbix.dump
```

## Volume backup

Stop writers briefly for a consistent Loki, Jaeger, and Grafana snapshot:

```powershell
docker compose stop otel-collector grafana loki jaeger
```

Archive each volume, replacing `zabbix-obs` if `COMPOSE_PROJECT_NAME` differs:

```powershell
$volumes = @('grafana', 'loki', 'jaeger')
foreach ($name in $volumes) {
    docker run --rm `
        --mount "type=volume,source=zabbix-obs-$name,target=/source,readonly" `
        --mount "type=bind,source=$backupRoot,target=/backup" `
        alpine:3.22.1 tar -czf "/backup/$name.tgz" -C /source .
}

docker compose up -d
docker compose ps
```

Record checksums before transferring the backup:

```powershell
Get-FileHash (Join-Path $backupRoot '*') -Algorithm SHA256 |
    Format-Table -AutoSize
```

The helper image is version-pinned but should still be approved and scanned in controlled environments.

## Restore prerequisites

1. Isolate the restore target from production senders and users.
2. Install the same Compose and component versions used for the backup.
3. Restore the original Grafana secret key; otherwise encrypted Grafana data-source credentials cannot be decrypted.
4. Create `.env` and validate it with `docker compose config --quiet`.
5. Preserve the original backup and work from a copy.

## Restore PostgreSQL

Start only PostgreSQL and wait for it to become healthy:

```powershell
docker compose up -d postgres
docker compose ps postgres
```

Copy and restore the dump into a new, empty Zabbix database. The following destructive commands are appropriate only on the isolated restore target:

```powershell
$postgresId = docker compose ps -q postgres
docker cp (Join-Path $backupRoot 'zabbix.dump') "${postgresId}:/tmp/zabbix.dump"

docker compose exec -T postgres dropdb -U zabbix --if-exists zabbix
docker compose exec -T postgres createdb -U zabbix -O zabbix zabbix
docker compose exec -T postgres pg_restore `
    -U zabbix -d zabbix --no-owner --no-privileges /tmp/zabbix.dump
docker compose exec -T postgres rm -f /tmp/zabbix.dump
```

Use configured database/user names if they differ. Do not drop a production database to test a restore.

## Restore named volumes

Ensure the target services are stopped. Restore each archive into its empty named volume:

```powershell
docker compose stop grafana loki jaeger otel-collector

$volumes = @('grafana', 'loki', 'jaeger')
foreach ($name in $volumes) {
    docker run --rm `
        --mount "type=volume,source=zabbix-obs-$name,target=/target" `
        --mount "type=bind,source=$backupRoot,target=/backup,readonly" `
        alpine:3.22.1 sh -c "rm -rf /target/* /target/.[!.]* /target/..?* 2>/dev/null; tar -xzf /backup/$name.tgz -C /target"
}

docker compose up -d
```

Loki can return `503 Service Unavailable` briefly while its single-node ring
initializes and restored state is loaded. Wait for readiness before validating
retained logs; a one-time `empty ring` message during this startup interval is
expected, but repeated errors after Loki is ready require investigation.

## Restore validation

- Confirm every expected container is running or healthy.
- Sign in with a named Zabbix and Grafana account.
- Confirm Zabbix hosts, history, triggers, actions, and media types.
- Confirm Grafana data sources and dashboards.
- Query a known retained Loki log and Jaeger trace.
- Send a new test log, trace, and Zabbix value.
- Trigger and recover a test notification.
- Review logs for database migration or permission errors.
- Record restore duration and any manual correction needed.

Only reconnect senders and users after validation succeeds.

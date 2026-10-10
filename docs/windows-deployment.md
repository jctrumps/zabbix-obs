# Windows 10/11 deployment

This procedure runs the Linux container stack through Docker Desktop. It is suitable for evaluation, development, and a small internal workstation deployment. A Windows laptop is not an always-on monitoring server: sleep, user logoff, Docker Desktop updates, and Windows restarts interrupt monitoring. Use the Debian VM deployment in [deployment.md](deployment.md) when availability matters.

## 1. Confirm suitability

Use a currently supported 64-bit Windows 10 or Windows 11 release with hardware virtualization enabled. Docker's current WSL 2 requirements include at least 8 GB of system RAM; this complete stack is more comfortable on a 16 GB or larger system with at least 100 GB free SSD space.

Check Docker Desktop's current Windows requirements and license terms before installation. Commercial use in larger organizations and government use may require a paid Docker subscription.

The user operating Docker can control the containers and read their environment, including secrets. Treat Docker access as administrative access and do not grant it to ordinary Grafana or Zabbix users.

## 2. Install WSL 2

Open PowerShell as Administrator:

```powershell
wsl --install
wsl --update
```

Restart Windows if requested. Verify:

```powershell
wsl --version
wsl --status
systeminfo.exe
```

If virtualization is reported disabled, enable Intel VT-x/VT-d or AMD-V/SVM in UEFI/BIOS. Corporate endpoint policy may prevent WSL or Docker Desktop; resolve that with the Windows administrator rather than bypassing policy.

## 3. Install Docker Desktop

1. Download Docker Desktop only from Docker or the Microsoft Store.
2. Prefer the per-user installation unless organizational management requires all-users mode.
3. Select the WSL 2 backend.
4. Start Docker Desktop and use Linux containers. This project does not run as Windows containers.
5. In Docker Desktop settings, allocate approximately 4 CPUs, 8 GB RAM, and enough disk capacity for the 100 GB starting target.
6. Keep Docker Desktop and WSL updated through the organization's normal patch process.

Verify from a normal PowerShell window:

```powershell
docker version
docker compose version
docker context show
```

Both client and server details must appear in `docker version`. A named-pipe connection error means Docker Desktop is not running or the Linux engine is unavailable.

## 4. Prepare the project

Use a local NTFS path such as `C:\Projects\zabbix-obs`. Avoid OneDrive, network shares, removable disks, and paths synchronized by backup tools while containers are running.

From the repository root in PowerShell:

```powershell
Copy-Item -LiteralPath '.env.example' -Destination '.env'
```

Generate three independent cryptographic secrets:

```powershell
function New-RandomSecret {
    $bytes = [byte[]]::new(32)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    [Convert]::ToBase64String($bytes)
}

New-RandomSecret
New-RandomSecret
New-RandomSecret
```

Open `.env` in a trusted text editor and replace all three `CHANGE_ME` values. Use one generated value for each setting:

- `ZABBIX_DB_PASSWORD`
- `GRAFANA_ADMIN_PASSWORD`
- `GRAFANA_SECRET_KEY`

Do not reuse a Windows, domain, database, or personal password. Keep `.env` out of email, tickets, source control, screenshots, and shared folders. The project `.gitignore` excludes it, but that is not a substitute for checking changes before publishing.

Leave all bind addresses at `127.0.0.1` for the initial deployment. Set `TZ` and leave `GRAFANA_ROOT_URL=http://localhost:3000` for local access.

## 5. Validate and start

Ensure Docker Desktop shows **Engine running**, then run:

```powershell
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
```

The first pull is several gigabytes and initial Zabbix database creation may take several minutes. Inspect failures without printing the `.env` file:

```powershell
docker compose logs --tail 200 postgres zabbix-server zabbix-web
docker compose logs --tail 200 grafana loki otel-collector jaeger
```

Verify local endpoints:

```powershell
Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:8080/' | Select-Object StatusCode
Invoke-RestMethod 'http://127.0.0.1:3000/api/health'
Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:16686/' | Select-Object StatusCode
```

Loki port 3100 is intentionally unavailable from Windows. Applications send logs and traces to OTLP on `127.0.0.1:4317` or `http://127.0.0.1:4318`; Grafana reaches Loki inside Docker.

## 6. Complete first login

1. Browse to <http://127.0.0.1:8080>.
2. Sign in to Zabbix with `Admin` / `zabbix` and immediately replace that bootstrap password.
3. Create a named Zabbix administrator for each operator; use non-admin roles for viewers.
4. Browse to <http://127.0.0.1:3000> and sign in with the Grafana credentials from `.env`.
5. Create named Grafana users or integrate the organization's existing identity provider through an approved HTTPS endpoint.
6. Follow [grafana.md](grafana.md) to create the read-only Zabbix integration.
7. Test alert delivery and recovery before relying on the system.

Do not give users Docker Desktop access just to view dashboards. Give them Zabbix or Grafana accounts with least-privilege roles.

## 7. Allow other Windows or LAN users

The safest access method is the organization's VPN or Zero Trust service plus an HTTPS reverse proxy. This Compose project intentionally does not include an edge proxy because certificate issuance and identity policy are environment-specific.

Plain HTTP is acceptable only for loopback evaluation. Before any network user signs in, provide HTTPS. Zabbix and Grafana passwords otherwise cross the network without transport encryption, and Jaeger has no login at all.

If direct private-LAN publishing is temporarily required:

1. Set the Windows network profile to **Private**, not Public.
2. Set `ADMIN_BIND_ADDRESS=0.0.0.0` in `.env`.
3. Set `GRAFANA_ROOT_URL` to the exact user-facing URL.
4. Recreate the affected containers with `docker compose up -d`.
5. Add inbound Windows Firewall rules scoped to exact administrator subnets.
6. Verify from an allowed machine and from a machine that should be denied.

Example from elevated PowerShell, replacing the example subnet:

```powershell
New-NetFirewallRule -DisplayName 'zabbix-obs admin UIs' `
    -Direction Inbound -Action Allow -Protocol TCP `
    -LocalPort 3000,8080 -RemoteAddress 192.0.2.0/24 -Profile Private
```

Do not expose port 16686 to ordinary users. If administrators require Jaeger, put it behind the authenticated HTTPS edge or create a separately scoped firewall rule.

For remote Zabbix agents, set `ZABBIX_BIND_ADDRESS=0.0.0.0` only after restricting TCP 10051 to agent/proxy networks. Configure Zabbix Agent 2 with PSK or certificate encryption. For remote OTLP senders, set `TELEMETRY_BIND_ADDRESS=0.0.0.0` only on a trusted network; this baseline has no OTLP authentication or TLS, so a gateway or a collector configuration with TLS/mTLS is required across untrusted networks.

Never create a broad inbound allow rule for all listed ports. Loki 3100, PostgreSQL 5432, Jaeger collector ports, and container-internal health ports do not need Windows firewall rules.

## 8. Day-two operation

View state and resource use:

```powershell
docker compose ps
docker stats --no-stream
docker compose logs --since 30m
Get-Volume
```

Stop and start without deleting data:

```powershell
docker compose stop
docker compose start
```

Docker named volumes live in Docker Desktop's Linux data disk, not beside this repository. Back up application data using [backup-restore.md](backup-restore.md); copying the project directory is not a data backup.

If using Ansible from WSL, keep the Ansible checkout in the WSL Linux filesystem. Ansible considers Windows-mounted `/mnt/c` directories world-writable and ignores a project-local `ansible.cfg`; see `deploy/ansible/README.md` for the explicit role-path fallback.

Disable Windows sleep and hibernation only if this workstation is intentionally serving monitoring continuously and organizational power policy permits it. Plan for Windows Update reboots and confirm Docker Desktop starts after sign-in. These limitations are why the Linux VM is the production recommendation.

## 9. Troubleshooting

Check port conflicts:

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalPort -In 3000,4317,4318,8080,10051,16686
```

Common causes:

- **Cannot connect to Docker named pipe:** start Docker Desktop and confirm Linux containers are selected.
- **WSL kernel error:** run `wsl --update`, then `wsl --shutdown`, and restart Docker Desktop.
- **A port is already in use:** stop the conflicting program or change the corresponding host port in `.env`.
- **Container repeatedly restarts:** inspect `docker compose logs <service>` and verify available RAM and disk.
- **Grafana password from `.env` no longer works:** the environment password initializes only a new Grafana database; reset the existing account through Grafana's supported administration command.
- **LAN access fails:** verify the bind address, Windows network profile, scoped firewall rule, endpoint security policy, and Docker Desktop networking mode.
- **Poor bind-mount performance:** keep the repository on a local disk and ensure Docker Desktop is using WSL 2; persistent application data already uses named volumes.

## 10. Remove the deployment

Retain data while removing containers:

```powershell
docker compose down
```

Do not add `-v` unless decommissioning is approved and backups have been verified. `docker compose down -v` permanently removes PostgreSQL, Grafana, Loki, and Jaeger named volumes.

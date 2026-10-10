# Deployment guide

This guide covers a single-node deployment. Use Windows 10/11 for local evaluation or a small workstation deployment; use a dedicated Linux VM for an always-on environment. The stack is not highly available.

For a Windows walkthrough, see [windows-deployment.md](windows-deployment.md). Review [security.md](security.md) before allowing remote access and [backup-restore.md](backup-restore.md) before storing data that matters.

## 1. Capacity and prerequisites

Recommended initial capacity:

- 4 vCPU
- 8 GB RAM dedicated to the stack; 16 GB host RAM is preferable
- 100 GB SSD with monitoring for free space
- reliable DNS and NTP
- a static private address for a server deployment
- Docker Engine 28 or later and Docker Compose v2

The Linux automation targets Debian 13. The operator workstation also needs Ansible for configuration and OpenTofu only when provisioning Proxmox.

## 2. Obtain and inspect the project

Keep the repository on a trusted administrative workstation. Review the pinned image versions in `.env.example` and release notes before deploying. Image tags are pinned to versions but are not immutable digests; a controlled production environment should record resolved image digests and scan them before promotion.

Do not run this project from an untrusted fork. The Docker daemon and Ansible deployment account are privileged execution paths.

## 3. Create configuration and secrets

On Linux or in WSL:

```bash
cp .env.example .env
chmod 600 .env
openssl rand -base64 32
openssl rand -base64 32
openssl rand -base64 32
```

Put the three independent generated values in:

- `ZABBIX_DB_PASSWORD`
- `GRAFANA_ADMIN_PASSWORD`
- `GRAFANA_SECRET_KEY`

The Grafana secret key protects encrypted values stored in Grafana's database. Do not change it after data sources or other secrets have been saved unless you follow Grafana's secret-key rotation procedure.

Also set:

- `TZ` to a valid IANA time zone
- `GRAFANA_ROOT_URL` to the final URL users will open
- bind addresses as described below

The default bind addresses are `127.0.0.1`; this is the safe local-only mode. Never commit `.env`, vault passwords, API tokens, backups, or OpenTofu state.

## 4. Validate and start

```bash
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
```

Initial database creation can take several minutes. Follow startup if a service does not become healthy:

```bash
docker compose logs --tail 200 postgres zabbix-server zabbix-web
docker compose logs --tail 200 grafana loki otel-collector jaeger
```

Do not use `docker compose down -v` during troubleshooting. The `-v` option deletes all named volumes.

## 5. Network exposure

Published ports bind to loopback by default:

| Variable | Port | Purpose | Authentication in this stack |
|---|---:|---|---|
| `ADMIN_BIND_ADDRESS` | 8080 | Zabbix UI/API | Zabbix login; HTTP only |
| `ADMIN_BIND_ADDRESS` | 3000 | Grafana UI | Grafana login; HTTP only |
| `ADMIN_BIND_ADDRESS` | 16686 | Jaeger UI/API | None |
| `ZABBIX_BIND_ADDRESS` | 10051 | Zabbix server/trapper | Protocol controls; configure agent TLS/PSK |
| `TELEMETRY_BIND_ADDRESS` | 4317 | OTLP gRPC | None; plaintext |
| `TELEMETRY_BIND_ADDRESS` | 4318 | OTLP HTTP | None; plaintext |

Loki is deliberately not published on the host. Grafana and the collector reach it over the Compose network.

For a server, set ingestion bind addresses to the VM's private address only when remote senders need them. Restrict port 10051 to monitored networks or Zabbix proxies, and restrict 4317/4318 to known telemetry senders. Keep Jaeger limited to administrators because it has no login and traces may contain sensitive data.

For multi-user UI access, terminate HTTPS and enforce access policy in an existing reverse proxy, VPN, or Zero Trust edge. Do not send user credentials over plain HTTP across a network. The edge component is intentionally outside this Compose project.

## 6. Linux host preparation

Before Ansible deployment:

1. Install Debian 13 and all security updates.
2. Create a named administrative account using SSH keys.
3. Disable direct remote root login and password SSH after key access is tested.
4. Configure NTP and a static private address or DHCP reservation.
5. Apply a host firewall with default-deny inbound rules while preserving SSH access.
6. Permit UI and ingestion ports only from their required source networks.
7. Put `/var/lib/docker` on storage with sufficient capacity and monitoring.
8. Configure encrypted, off-host backups.

Docker-published ports can interact with Linux firewall tooling differently from ordinary host processes. Verify the effective rules from another machine; do not assume a host firewall rule is working merely because it exists.

## 7. Deploy with Ansible

Install the collection on the control host:

```bash
cd deploy/ansible
ansible-galaxy collection install -r requirements.yml
```

Copy the example inventory to the ignored `local/` directory before adding real addresses or credentials. Store deployment secrets in Ansible Vault rather than plaintext group variables:

```bash
mkdir -p local/inventories
cp -R inventories/prod local/inventories/prod
# Edit the copied hosts.yml and group_vars/all.yml with real deployment values.
ansible-vault encrypt local/inventories/prod/group_vars/all.yml
ansible-playbook -i local/inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass --check
ansible-playbook -i local/inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass
```

The role rejects missing, short, and placeholder secrets. It writes `/opt/zabbix-obs/.env` as root with mode `0600`, copies the managed configuration, pulls the pinned tags, and starts the stack. Set the following inventory values for remote access only after firewall policy is in place:

```yaml
admin_bind_address: 192.0.2.30
zabbix_bind_address: 192.0.2.30
telemetry_bind_address: 192.0.2.30
grafana_root_url: https://grafana.example.com
```

Use the actual private address, not the documentation-only address shown above.

## 8. Provision with OpenTofu on Proxmox

OpenTofu creates a VM by cloning an existing cloud-init template; it does not build or secure that template.

```bash
cd deploy/opentofu/proxmox
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu fmt -check
tofu validate
tofu plan -out=tfplan
tofu apply tfplan
```

Use a least-privilege Proxmox API token and a trusted TLS certificate. Keep `proxmox_insecure_tls = false`. The local state can contain infrastructure details and must be access-controlled and backed up; configure a protected remote state backend before multiple operators manage the deployment.

After provisioning, place the VM address in the Ansible inventory and run the Ansible deployment.

## 9. First login and user setup

1. Open Zabbix at `http://127.0.0.1:8080` locally or through the approved HTTPS edge.
2. Sign in with the upstream bootstrap account `Admin` / `zabbix` and immediately set a unique password.
3. Create named administrator accounts, test them, then stop routine use of the bootstrap account.
4. Create Zabbix user groups and roles with only the required host-group permissions.
5. Open Grafana at `http://127.0.0.1:3000` and sign in with the `.env` admin credentials.
6. Create named users and teams; do not share the Grafana administrator account.
7. Configure the Zabbix Grafana data source using [grafana.md](grafana.md).
8. Configure notification media, escalation policy, and a test alert in Zabbix.
9. Configure agent encryption using PSK or certificates before monitoring hosts across untrusted network segments.

Changing `GRAFANA_ADMIN_PASSWORD` in `.env` after Grafana's first start does not rotate the database account password. Change it in Grafana or use Grafana's documented administrative reset command.

## 10. Acceptance checks

Complete these before declaring the service ready:

```bash
docker compose config --quiet
docker compose ps
docker compose exec otel-collector /otelcol-contrib validate --config=/etc/otelcol-contrib/config.yaml
```

Also verify:

- Zabbix reports the server running and has no unsupported internal items.
- Grafana's Loki and Jaeger provisioned data sources pass their tests.
- The dedicated Zabbix data source account can read data but cannot administer Zabbix.
- A test host reports through an encrypted Zabbix Agent 2 connection.
- A synthetic trace and log reach Jaeger and Loki through the collector.
- Notifications reach the on-call test recipient and recover correctly.
- Unapproved source networks cannot reach any published port.
- A backup completes and a restore has been tested on a separate instance.

## 11. Routine operation and upgrades

Before every upgrade:

1. Read each component's release and upgrade notes.
2. Take and verify a backup.
3. Update one service family at a time in a non-production environment.
4. Run `docker compose config --quiet` and scan the new images.
5. Pull and recreate the selected service.
6. Verify ingestion, dashboards, alert delivery, retention, and resource use.
7. Record the resolved image digest and result.

Example:

```bash
docker compose pull grafana
docker compose up -d --no-deps grafana
docker compose ps
docker compose logs --tail 100 grafana
```

Database schema upgrades can prevent rollback. A previous image is not a rollback plan without a compatible database backup.

## 12. Stop or remove

Stop while retaining data:

```bash
docker compose stop
```

Remove containers and networks while retaining named volumes:

```bash
docker compose down
```

Only after a verified backup and explicit decommission approval, delete all named volumes with `docker compose down -v`.

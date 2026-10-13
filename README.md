# zabbix-obs

A reproducible, single-VM observability platform. **Zabbix owns infrastructure
health and alerting**, Loki stores logs, Jaeger stores traces, OpenTelemetry
Collector routes telemetry, and Grafana provides dashboards. PostgreSQL is
Zabbix application storage. Grafana alerting is disabled.

```text
Windows CMD + native OpenTofu → Proxmox VE → Debian 13 VM
Windows CMD → WSL Ubuntu → SSH + Ansible → Docker Engine + Compose
                                             ├─ Zabbix + PostgreSQL
                                             ├─ Grafana
                                             └─ Collector → Loki / Jaeger 2
```

## Start here

1. **[Windows CMD → WSL → Ansible first-run guide](docs/windows-wsl-ansible.md)** — the canonical deployment path.
2. [Prerequisites](docs/prerequisites.md) — workstation tools, template contract and local values.
3. [Daily deployment](docs/daily-deployment.md) — repeat deployments after onboarding.
4. [Native Linux deployment](docs/linux-deployment.md) — separate Linux operator workflow.
5. [Operations](docs/operations.md) and [backup/restore](docs/backup-restore.md).
6. [Manual Cloudflare Tunnel](docs/cloudflare-tunnel.md) — only after internal verification.

See the [ordered documentation index](docs/README.md) for all guides and the
[validation report](docs/validation-report.md) for checks actually performed.

## Supported platform and capacity

- Proxmox VE with an existing, prepared cloud-init template; provider `bpg/proxmox` is locked.
- Debian 13 amd64 by default; Ubuntu 24.04 LTS amd64 also supported.
- Initial VM: 4 vCPU, 8 GiB RAM, 100 GiB SSD. Single-node, not highly available.
- Native Windows OpenTofu 1.9+; WSL2 Ubuntu with Python 3.12+ and Ansible.
- Docker Engine and Compose plugin are installed by Ansible on the guest.
- Docker Desktop is optional for local static Compose checks, not required for VM deployment.

## Git-safe setup

Copy `deploy/opentofu/proxmox/terraform.tfvars.example` to the ignored filled
file and `deploy/ansible/inventory/hosts.ini.example` to ignored `hosts.ini`.
The runbook walks through every value and command. Real secrets live outside
the checkout in `~/.config/zabbix-obs/vault.yml` (Ansible Vault). The unique SSH
key is `zabbix_obs_ed25519`, generated in Windows and copied to WSL `~/.ssh`.
Never commit state, plans, private keys, filled inventories, runtime exports or
real infrastructure details. Review [public release](docs/public-release.md).

## Layout

| Path | Role |
|---|---|
| `deploy/opentofu/proxmox/` | VM clone, cloud-init key/user/network and connection outputs |
| `deploy/ansible/` | Guest configuration, Docker installation and stack convergence |
| `docker-compose.yml`, `.env.example` | Pinned application images and configuration schema |
| `grafana/`, `loki/`, `otel/`, `jaeger/` | Managed application configuration |
| `docs/` | Onboarding, operation, recovery and validation |
| `scripts/` | Local source validation and source-only ZIP packaging |

## Quick reference and verification

**WINDOWS CMD**, after completing first-time setup:

```bat
cd /d "C:\Projects\zabbix-obs\deploy\ansible"
wsl
```

Then follow the short [WSL daily commands](docs/daily-deployment.md), including
`ANSIBLE_CONFIG`, SSH agent, Vault and the actual playbook path.

On the **REMOTE VM**, `sudo docker compose --project-directory /opt/zabbix-obs ps`
shows container state. Use the internal probes in [operations](docs/operations.md).
Access from the workstation uses verified SSH forwarding or the manual tunnel:

| VM loopback endpoint | Purpose |
|---|---|
| `http://127.0.0.1:8080` | Zabbix UI/API |
| `http://127.0.0.1:3000` | Grafana |
| `http://127.0.0.1:16686` | Jaeger UI, no built-in login |
| `127.0.0.1:10051` | Zabbix agent/proxy ingestion |
| `127.0.0.1:4317`, `127.0.0.1:4318` | OTLP ingestion, plaintext by default |

PostgreSQL and Loki are not host-published. All published ports default to VM
loopback. Restrict any changed ingestion bindings to trusted senders and configure
transport encryption before crossing untrusted networks. Change the initial
Zabbix `Admin` / `zabbix` password at first login. Configure the read-only Grafana
integration and real Zabbix notifications before relying on alerts.

## Persistence and maintenance

Named volumes: `zabbix-obs-postgres`, `zabbix-obs-grafana`, `zabbix-obs-loki`,
`zabbix-obs-jaeger-v2`. Source checkout copies do not back these up. Image/schema
upgrades require a compatible backup for rollback. Existing Jaeger 1 operators
must read the [migration section](docs/operations.md#jaeger-1-to-2-transition)
before deployment. Follow [security](docs/security.md) and [backup/restore](docs/backup-restore.md).

Contributions follow [CONTRIBUTING.md](CONTRIBUTING.md). Original IaC and
documentation are MIT licensed: [LICENSE](LICENSE). Upstream applications retain
their own licenses.

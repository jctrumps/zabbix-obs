# Prerequisites

## Operator workstation

**WINDOWS CMD:** use supported Windows, native OpenSSH and OpenTofu 1.9+,
WSL2 Ubuntu 24.04+ (Python 3.12+) and a trusted checkout. Git is useful for
updates/publication; Python 3 is needed only for source validation/ZIP helpers.
Docker Desktop is optional for `docker compose config` checks. Install steps
and the project key are in [phase A](windows-wsl-ansible.md#a--workstation-prerequisites-and-a-unique-ssh-key).

The workstation needs HTTPS access to Proxmox and outbound dependency registries;
WSL needs SSH access to the guest and HTTPS to Ansible Galaxy. The guest needs
DNS/NTP, outbound HTTPS for apt/container registries and Grafana plugin download.

## Proxmox and template contract

**PROXMOX WEB INTERFACE:** identify an existing Debian 13 amd64 template
(Ubuntu 24.04 amd64 is also supported), source/target node, free VM ID,
datastore and bridge. Review Hardware and Cloud-Init settings:

- A cloud-init disk and clean first-boot state; cloned host SSH keys must be regenerated.
- Boot disk on `scsi0` with `virtio-scsi-pci`, or set the module variables to
  match your template. Other template disks/firmware are inherited. This module
  manages/resizes one boot disk; inspect clones carefully if your template has extras.
- Disk no larger than requested clone size. Default 100 GiB, 4 vCPU, 8 GiB RAM.
- Installed and running qemu-guest-agent when `agent_enabled = true`.
- SSH server, Python 3, sudo; cloud-init creates the configured non-root user,
  supplies the key and grants usable sudo according to the template's policy.
- Working time synchronization, package repositories and cloud-init networking.

The public [proxmox-debian13](https://github.com/jctrumps/proxmox-debian13)
project is a template preparation reference. Template creation is a separate
operator prerequisite; this repository does not modify your Proxmox hosts.
Confirm the template works before cloning. If the agent is absent, prepare the
template or explicitly disable the agent and use the console/DHCP lease for IP
discovery; Ansible installs the agent later.

## Values to supply locally

| Value | Location |
|---|---|
| Proxmox endpoint, node/template, datastore, bridge, VM ID, sizing | Ignored `deploy/opentofu/proxmox/terraform.tfvars` |
| Least-privilege API token | Credential-manager environment or ignored `credentials.auto.tfvars` |
| Trusted Proxmox CA / certificate chain | Workstation trust; keep `proxmox_insecure_tls = false` |
| DHCP reservation or real CIDR/gateway/DNS | Local tfvars |
| Public key path and guest user | Local tfvars; default `zabbix_obs_ed25519.pub` / `debian` |
| Actual VM IP/user | Ignored `deploy/ansible/inventory/hosts.ini` |
| Three independent application secrets | Outside checkout, encrypted `~/.config/zabbix-obs/vault.yml` |
| Local non-secret overrides | Ignored `deploy/ansible/inventory/vars.yml` |
| Optional HTTPS URLs/Access policy | Local vars and manual Cloudflare dashboard |

Keep private keys, secrets and backups outside Git. Defaults such as `local-lvm`
and `vmbr0` are common examples, not claims about your environment. All
`192.0.2.0/24` addresses are documentation-only. Next: [first run](windows-wsl-ansible.md).

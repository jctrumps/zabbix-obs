# OpenTofu reference

Module: `deploy/opentofu/proxmox`. Provider: `bpg/proxmox ~> 0.111.1`, with the
checked-in lockfile selecting the actual build. OpenTofu 1.9+ is required.
The [provider VM schema](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm)
defines clone, disk, cloud-init and guest-agent behavior.

## Permissions, TLS and state

**PROXMOX WEB INTERFACE:** create a dedicated automation account/token scoped
to the source template, target VM/pool and target datastore. Grant effective
permissions needed for clone/allocation, VM CPU/memory/disk/network/cloud-init
configuration, VM audit/power management, datastore allocation/audit and node
audit. Token privilege separation intersects account and token permissions;
both must be sufficient. Use the provider's
[permissions guidance](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
for your Proxmox release. If a 403 occurs, identify the denied API operation
and adjust its scope; do not default to a root password/token.

Use a DNS endpoint matching a trusted certificate. Install your private CA in
the workstation's trust store through your administrator if needed. The TLS
insecure switch is available for deliberate lab configuration, not a recovery
shortcut. The module does not need SSH access to the Proxmox host for this clone.

The token variable is sensitive and optional; the provider also reads
`PROXMOX_VE_API_TOKEN`. Entering a token into an editor avoids exposing it in
shell history. Ignored files still need access controls. Local state contains
addresses, resource details and cloud-init inputs; saved plans may contain
secrets. Keep state encrypted/backed up. Use a protected remote backend with
locking before multiple operators share management. Never delete state as an
error-recovery technique.

## Inputs and outputs

`variables.tf` and `terraform.tfvars.example` cover API/TLS, node/template,
VM ID/name/description/tags, CPU type/cores, RAM, boot disk/interface/controller,
datastore, bridge, on-boot, agent, DHCP/static addressing/gateway/DNS and SSH
username/public-key path. Firmware and additional template devices are inherited;
verify them in the plan against [the template contract](prerequisites.md).
`agent_enabled` must reflect an installed, running agent. Public-key paths are
resolved on the machine running OpenTofu. No private key enters state.

Outputs include VM ID/name, `ssh_username`, `configured_ipv4` for static
addressing, and guest-agent address/interface lists. Pick the actual reachable
LAN address and enter it into local Ansible inventory; no inventory is generated.

## Lifecycle — WINDOWS CMD

First-time setup, from the real module directory:

```bat
cd /d "C:\Projects\zabbix-obs\deploy\opentofu\proxmox"
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
notepad credentials.auto.tfvars
tofu init
tofu fmt -check
tofu validate
tofu plan
tofu apply
tofu output
```

Configure credentials as shown in the canonical runbook. Review every proposed
change and approve apply interactively. To update observed state without changing
remote resources, **WINDOWS CMD**, same directory:

```bat
tofu plan -refresh-only
tofu apply -refresh-only
```

The latter still changes state after confirmation. Do not use refresh to hide
unexplained drift. Provider upgrades are explicit: edit the constraint, run
`tofu init -upgrade`, review lockfile changes and validate before applying.

### Decommission — WINDOWS CMD, only when intentionally retiring the VM

Back up and test recovery first. This removes the managed VM and its disks,
including Docker volumes; stopping containers is not equivalent.

```bat
cd /d "C:\Projects\zabbix-obs\deploy\opentofu\proxmox"
tofu plan -destroy
tofu destroy
```

Read the destruction plan and confirm only if this is the intended VM.
The project does not automate apply/destroy. Next: [Ansible](ansible.md).

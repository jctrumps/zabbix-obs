# Project status

The repository now implements the supplied infrastructure-generation standard:
native Windows OpenTofu, a cloud-init SSH handoff, same-checkout WSL Ansible,
explicit inventory/Vault configuration and canonical first-run/daily guides.

The application remains a single-node Zabbix-centered stack. Jaeger is now 2.x
with a separate persistent volume. See [operations](docs/operations.md) before
upgrading an existing v1 deployment.

Current checks and untested assumptions are recorded in
[validation report](docs/validation-report.md). Earlier runtime/recovery results
in this file referred to the prior stack and are not evidence for this revision.

Operator acceptance still includes provisioning, SSH/sudo, two-pass Ansible
convergence, health and telemetry, first login, host registration, alert delivery,
off-host backup/restore and optional manual external access. Start at
[the Windows/WSL runbook](docs/windows-wsl-ansible.md).

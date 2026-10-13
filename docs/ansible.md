# Ansible reference

Control directory: `deploy/ansible`; playbook: `playbooks/site.yml`; inventory
group: `observability`. The canonical commands, including Vault and identity
flags, are in [first run](windows-wsl-ansible.md) and [daily deployment](daily-deployment.md).

**WSL / UBUNTU BASH**, or **NATIVE LINUX**, from `deploy/ansible`:

```bash
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible --version
ansible-config dump --only-changed
ansible-galaxy collection install -r requirements.yml
ansible-inventory -i inventory/hosts.ini --list
```

Expected config is this directory's `ansible.cfg`; roles path must resolve to
`deploy/ansible/roles`. `/mnt/c` may suppress automatic config discovery: select
only a trusted config explicitly. See phase F for the native-WSL fallback.
Inventory output contains local details; do not publish it.

## Inputs

| Variable | Default / source |
|---|---|
| `ansible_host`, `ansible_user` | Local inventory, from OpenTofu/console |
| Private identity | Explicit `--private-key ~/.ssh/zabbix_obs_ed25519` |
| `zabbix_db_password`, `grafana_admin_password`, `grafana_secret_key` | External encrypted Vault, three independent base64 random values |
| `obs_stack_dir` | `/opt/zabbix-obs` |
| `obs_compose_project_name` | `zabbix-obs`; changing it creates different named volumes |
| `obs_repo_source` | Calculated repository root relative to `playbooks/site.yml` |
| `timezone` | `UTC` |
| `admin_bind_address`, `zabbix_bind_address`, `telemetry_bind_address` | `127.0.0.1` |
| `grafana_root_url` | `http://localhost:3000` |
| `obs_upgrade_os`, `obs_upgrade_docker` | `false`; opt in during maintenance |

Every other Compose environment setting is represented by its lowercase name
in `roles/zabbix-obs/templates/env.j2`, except `TZ` → `timezone`,
`COMPOSE_PROJECT_NAME` → `obs_compose_project_name`, and `OTEL_IMAGE` →
`otel_image`. Image defaults mirror `.env.example` and Compose. Use
`inventory/vars.yml` for non-secret overrides; it is passed explicitly via
`-e @inventory/vars.yml`. Use `--ask-vault-pass -e @"$HOME/.config/zabbix-obs/vault.yml"`
for secrets. `secrets.yml.example` is the schema. Never store plaintext real
secrets under the Git working tree, even in ignored files.

## Behavior and reruns

The Docker role validates the guest OS, installs prerequisites and official
Docker packages from a signed apt repository, and enables Docker/guest agent.
Use a clean template without conflicting distribution Docker/containerd packages;
inspect existing workloads before removing conflicts. OS/Docker upgrades are
explicit maintenance switches. No automatic reboot is performed.

The stack role rejects placeholders/unsafe or reused secrets, copies managed
configs, renders a root-owned `0600` `.env` with output/diffs suppressed, checks
Compose syntax, converges containers and polls readiness. Secrets can still be
read by guest root and Docker administrators. Changed managed bind-mount
configuration triggers container recreation; see [operations](operations.md).

Use `--syntax-check` for local validation. Initial `--check` cannot simulate an
uninstalled Docker engine; test a real first deployment on a disposable VM.
Reapply to test convergence. `ping` requires remote Python and working SSH.
The playbook uses `become: true`; append `--ask-become-pass` where sudo requires it.

Existing users of the old `inventories/dev|staging|prod` examples should move
their local host entry to `inventory/hosts.ini`, non-secrets to `inventory/vars.yml`,
and encrypted secrets outside the checkout. The old local-execution dev inventory
was removed to avoid accidentally configuring the control workstation.

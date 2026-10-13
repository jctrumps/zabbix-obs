# Contributing

Keep Zabbix authoritative for infrastructure monitoring/alerting, Loki for logs,
Jaeger for traces, Collector for routing and Grafana for visualization. Preserve
the Windows CMD → native OpenTofu → WSL Ubuntu → Ansible operator workflow.
Read [AGENTS.md](AGENTS.md) and [architecture](docs/architecture.md).

For changes, update matching examples/docs and avoid real local details. Keep
secret/state files outside review. Never test a change by applying to live
infrastructure without the operator's explicit authorization.

## Local checks

**WINDOWS CMD**, repository root:

```bat
python scripts/validate-source.py
docker compose --env-file .env.example config --quiet
cd deploy\opentofu\proxmox
tofu init -backend=false
tofu fmt -check
tofu validate
```

**WSL / UBUNTU BASH**, `deploy/ansible`:

```bash
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible-galaxy collection install -r requirements.yml
ansible-inventory -i inventory/hosts.ini.example --list
ansible-playbook -i inventory/hosts.ini.example --syntax-check playbooks/site.yml
# If ansible-lint is installed:
ansible-lint playbooks/site.yml
```

Use disposable, explicitly approved targets for integration/restore testing.
Record actual checks and limitations in [validation report](docs/validation-report.md).
Review [public-release](docs/public-release.md) before sharing patches or ZIPs.

## License

Contributions to original repository code/docs are under the [MIT license](LICENSE).
Containerized upstream applications are not relicensed by this repository.

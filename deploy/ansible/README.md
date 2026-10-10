# Ansible deployment

Install the required collection:

```bash
ansible-galaxy collection install -r requirements.yml
```

The checked-in inventories are public examples. From `deploy/ansible`, copy the desired inventory into the ignored `local/` directory before replacing addresses and credentials. The role refuses to deploy placeholder, short, or missing secrets. Encrypt the copied variable file with Ansible Vault or source secrets from an approved external system:

```bash
mkdir -p local/inventories
cp -R inventories/prod local/inventories/prod
# Edit local/inventories/prod/hosts.yml and group_vars/all.yml.
ansible-vault encrypt local/inventories/prod/group_vars/all.yml
```

Deploy:

```bash
ansible-playbook -i local/inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass --check
ansible-playbook -i local/inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass
```

The role copies the core stack files, renders a root-only `.env`, and starts the Compose project. Bind addresses default to loopback. Define `admin_bind_address`, `zabbix_bind_address`, and `telemetry_bind_address` only after host/network firewall rules are in place.

Use the same copy workflow for `dev` or `staging`. Keep the checked-in examples generic; encrypted inventory files can still reveal hostnames, addresses, and usernames outside their encrypted sections.

Ansible does not run natively as a Windows control node. Windows administrators can run it from WSL 2 or a dedicated Linux administration host. The managed observability host remains Debian/Linux.

Prefer keeping the checkout in WSL's Linux filesystem. Ansible treats a project under `/mnt/c` as world-writable and ignores its `ansible.cfg`. If a Windows-mounted checkout must be used, explicitly provide the role path:

```bash
ANSIBLE_ROLES_PATH="$PWD/roles" \
  ansible-playbook -i inventories/dev/hosts.yml playbooks/site.yml --syntax-check
```

# Ansible deployment

From Windows CMD enter this directory, then run `wsl`. Keep the checkout in
its mounted Windows location and explicitly select its trusted `ansible.cfg`.

- [Canonical Windows/WSL runbook](../../docs/windows-wsl-ansible.md)
- [Variables, roles, inventory and Vault](../../docs/ansible.md)
- [Daily deployment](../../docs/daily-deployment.md)
- [Native Linux](../../docs/linux-deployment.md)

Inventory template: `inventory/hosts.ini.example`. Playbook:
`playbooks/site.yml`. Real secrets belong outside the checkout.

# Daily deployment

For an already provisioned guest, prepared inventory, Vault and verified key.
One-time setup is in [the canonical runbook](windows-wsl-ansible.md).

## Windows CMD

```bat
cd /d "C:\Projects\zabbix-obs\deploy\ansible"
wsl
```

## WSL Ubuntu Bash

```bash
pwd
# If needed: cd /mnt/c/Projects/zabbix-obs/deploy/ansible
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
KEY_NAME=zabbix_obs_ed25519
ansible --version
# Only when the current agent does not already have this identity:
eval "$(ssh-agent -s)"
ssh-add "$HOME/.ssh/$KEY_NAME"
ansible all -i inventory/hosts.ini --private-key "$HOME/.ssh/$KEY_NAME" -m ping
ansible-playbook -i inventory/hosts.ini --private-key "$HOME/.ssh/$KEY_NAME" \
  -e @inventory/vars.yml -e @"$HOME/.config/zabbix-obs/vault.yml" \
  --ask-vault-pass playbooks/site.yml
ansible observability -i inventory/hosts.ini --private-key "$HOME/.ssh/$KEY_NAME" \
  --become -m ansible.builtin.command \
  -a 'docker compose --project-directory /opt/zabbix-obs ps'
```

Expected: SSH ping succeeds, recap has no failures/unreachable hosts and status
shows the services running. Add `--ask-become-pass` if your guest requires a sudo
password. Install collections again only if `requirements.yml` changed.
For failures and health probes see [operations](operations.md).

### Optional infrastructure change — Windows CMD

Exit WSL or open a separate CMD window. Back up data before changing VM storage
or any plan proposing replacement. Read the plan before approving apply.

```bat
cd /d "C:\Projects\zabbix-obs\deploy\opentofu\proxmox"
tofu init
tofu fmt -check
tofu validate
tofu plan
tofu apply
tofu output
```

Update the local Ansible inventory if the guest's address or login changed, and
reverify its host key through the console if the VM was replaced.

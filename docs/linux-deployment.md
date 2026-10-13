# Native Linux operator deployment

This independent alternative runs OpenTofu and Ansible on a native Linux
workstation. The primary Windows workflow remains [the canonical guide](windows-wsl-ansible.md).
Commands below are **NATIVE LINUX**, using Ubuntu 24.04+ as the workstation.
The guest defaults to Debian 13; all Proxmox/template requirements remain in
[prerequisites](prerequisites.md).

## 1. Tools and checkout

Install a native OpenTofu 1.9+ binary using the official
[Linux installation instructions](https://opentofu.org/docs/intro/install/).
Place a reviewed clone/extracted repository at `$HOME/projects/zabbix-obs`.

```bash
sudo apt update
sudo apt install -y openssh-client openssl pipx python3-venv
pipx install 'ansible-core==2.20.6'
export PATH="$HOME/.local/bin:$PATH"
tofu version
ansible --version
install -d -m 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -a 100 -f "$HOME/.ssh/zabbix_obs_ed25519" -C zabbix-obs-vm
cat "$HOME/.ssh/zabbix_obs_ed25519.pub"
```

Use a passphrase; do not overwrite an existing project key. Only the public key
is given to cloud-init. If tool versions fail, fix installation before proceeding.

## 2. Provision — NATIVE LINUX

```bash
cd "$HOME/projects/zabbix-obs/deploy/opentofu/proxmox"
umask 077
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
nano credentials.auto.tfvars
tofu init
tofu fmt -check
tofu validate
tofu plan
tofu apply
tofu output
```

Fill actual node/template/datastore/bridge, networking, VM ID and endpoint in
tfvars. `~/.ssh/zabbix_obs_ed25519.pub` now resolves to the Linux home. Enter
`proxmox_api_token = "automation@pve!zabbix-obs=YOUR_TOKEN_SECRET"` with the real
token in the credential file, or inject the provider environment variable from
a credential manager. State/credentials remain local and sensitive. Review the
plan before confirming apply. Failure recovery and destruction are described in
[OpenTofu](opentofu.md); translate only the directory navigation for Linux.

## 3. Verify SSH and inventory — NATIVE LINUX

In the **PROXMOX WEB INTERFACE**, open the guest console and obtain its actual IP,
cloud-init status and host-key fingerprint using the console commands in phase B
of the canonical guide. Back on **NATIVE LINUX**:

```bash
KEY_NAME=zabbix_obs_ed25519
eval "$(ssh-agent -s)"
ssh-add "$HOME/.ssh/$KEY_NAME"
# Replace these documentation-only values with your outputs:
VM_IP=192.0.2.10
VM_USER=debian
ssh -o IdentitiesOnly=yes -i "$HOME/.ssh/$KEY_NAME" "$VM_USER@$VM_IP"
```

Verify the fingerprint before accepting. On the **REMOTE VM**, verify
`cloud-init status --wait`, `python3 --version`, `sudo -n true`, then `exit`.
Do not continue if SSH or sudo fails; use [troubleshooting](troubleshooting.md).

## 4. Deploy — NATIVE LINUX

```bash
cd "$HOME/projects/zabbix-obs/deploy/ansible"
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible --version
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.ini.example inventory/hosts.ini
cp inventory/vars.yml.example inventory/vars.yml
nano inventory/hosts.ini
nano inventory/vars.yml
install -d -m 700 "$HOME/.config/zabbix-obs"
openssl rand -base64 32
openssl rand -base64 32
openssl rand -base64 32
ansible-vault create "$HOME/.config/zabbix-obs/vault.yml"
ansible-inventory -i inventory/hosts.ini --list
ansible all -i inventory/hosts.ini --private-key "$HOME/.ssh/$KEY_NAME" -m ping
ansible-playbook -i inventory/hosts.ini --private-key "$HOME/.ssh/$KEY_NAME" \
  -e @inventory/vars.yml -e @"$HOME/.config/zabbix-obs/vault.yml" \
  --ask-vault-pass --syntax-check playbooks/site.yml
ansible-playbook -i inventory/hosts.ini --private-key "$HOME/.ssh/$KEY_NAME" \
  -e @inventory/vars.yml -e @"$HOME/.config/zabbix-obs/vault.yml" \
  --ask-vault-pass playbooks/site.yml
```

Inventory uses the real VM IP/user and the `observability` group. Vault schema:
`secrets.yml.example`; use three independent generated values. Add
`--ask-become-pass` if required. Expected: `pong`, syntax success and recap with
zero failed/unreachable. Reapply to verify convergence, then run the **REMOTE VM**
checks and first-login steps in [operations](operations.md).

## 5. Browser access and repeat runs — NATIVE LINUX

```bash
ssh -N -o ExitOnForwardFailure=yes -o IdentitiesOnly=yes \
  -i "$HOME/.ssh/$KEY_NAME" \
  -L 8080:127.0.0.1:8080 -L 3000:127.0.0.1:3000 -L 16686:127.0.0.1:16686 \
  "$VM_USER@$VM_IP"
```

Visit localhost ports 8080, 3000 and 16686 from this workstation. If forwarding
fails, choose unused local ports; do not widen guest bindings to solve it.
Daily runs reuse step 4's ping/playbook commands with existing files and agent.
Next: [backup/restore](backup-restore.md), then optional
[manual Cloudflare](cloudflare-tunnel.md). No WSL tooling is used in this guide.

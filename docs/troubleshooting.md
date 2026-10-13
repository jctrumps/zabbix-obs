# Troubleshooting

Unless a row says otherwise, diagnostics run in **WSL / UBUNTU BASH** from
`deploy/ansible`. Use the actual VM IP/user and project key; `192.0.2.10` is a
documentation address. Return to the failing phase of the
[canonical runbook](windows-wsl-ansible.md) once its expected check passes.

| Symptom | Likely cause | Diagnostic command / location | Fix |
|---|---|---|---|
| `wsl` starts in wrong directory | Default distro/startup settings | `pwd`; WINDOWS CMD `wsl --list --verbose` | `cd /mnt/c/Projects/zabbix-obs/deploy/ansible`; select Ubuntu as Windows WSL default |
| Windows user/path differs from WSL | Independent user homes | `whoami; echo "$HOME"`; `cmd.exe /C 'echo %USERPROFILE%'` | Resolve Windows profile with `wslpath` as in phase D; do not substitute Linux username into a Windows profile path |
| Private key missing in WSL | Key not copied or wrong name | `ls -l "$HOME/.ssh/zabbix_obs_ed25519"` | Copy the existing Windows project key with phase D's `install -m 600` command |
| `UNPROTECTED PRIVATE KEY FILE` | Broad modes, often NTFS mount | `stat -c '%a %n' "$HOME/.ssh" "$HOME/.ssh/zabbix_obs_ed25519"` | Use native WSL home; `chmod 700 "$HOME/.ssh"`; `chmod 600 "$HOME/.ssh/zabbix_obs_ed25519"` |
| Agent unavailable / passphrase prompt / wrong identity | Agent session absent or missing key | `ssh-add -l`; `ssh -vvv -o IdentitiesOnly=yes -i "$HOME/.ssh/zabbix_obs_ed25519" debian@192.0.2.10` | Start `eval "$(ssh-agent -s)"`, then `ssh-add "$HOME/.ssh/zabbix_obs_ed25519"`; use explicit identity |
| `Permission denied (publickey)` | Public/private mismatch, wrong user or cloud-init failure | Verbose SSH above; REMOTE VM console `cloud-init status --long`; `sudo journalctl -u ssh -n 100` | Compare derived public key with cloud-init/authorized_keys; correct key/user; fix guest ownership through console |
| Wrong guest login user | Assumed `ubuntu` rather than configured `debian` | WINDOWS CMD in module: `tofu output -raw ssh_username`; console `getent passwd debian` | Use the actual configured cloud-init user in both SSH and inventory |
| Initial host key untrusted | First connection | REMOTE VM console `sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` | Compare with client before accepting; do not trust `ssh-keyscan` alone |
| Host-key mismatch | VM replacement, wrong IP or interception | `ssh-keygen -F 192.0.2.10`; trusted console fingerprint | Investigate first; only after verified replacement use `ssh-keygen -R 192.0.2.10`, then reconnect |
| VM unreachable / SSH timeout | Wrong IP, routing, VLAN, firewall, stopped guest | `ip route get 192.0.2.10`; `ssh -vvv -o ConnectTimeout=10 debian@192.0.2.10`; REMOTE VM console `ip -br address` | Correct IP/bridge/routing and allow SSH only from control networks; inspect Proxmox firewall/tasks |
| DNS lookup fails | Wrong name or resolver | `getent hosts pve.example.com`; WINDOWS CMD `nslookup pve.example.com` | Correct local endpoint/DNS; test the verified guest IP for SSH |
| Inventory empty/wrong host | Wrong path, missing group, unedited example | `ansible-inventory -i inventory/hosts.ini --graph`; `ansible-inventory -i inventory/hosts.ini --list` | Copy `.example`, fill real IP/user, retain `observability`, use explicit `-i` |
| Ansible ignores `ansible.cfg` on `/mnt/c` | World-writable mount discovery protection | `ansible --version`; `ls -ld . ansible.cfg` | Review trust/ACLs then `export ANSIBLE_CONFIG="$PWD/ansible.cfg"`; use native WSL trusted checkout if trust cannot be established |
| Roles/collections missing | Wrong cwd/config or missing collection | `ansible-config dump --only-changed`; `ansible-galaxy collection list` | Work in `deploy/ansible`; select config; `ansible-galaxy collection install -r requirements.yml` |
| Ansible Python/module error | Guest missing Python or wrong interpreter | `ssh debian@192.0.2.10 python3 --version`; inventory interpreter | Install Python via trusted console and set `/usr/bin/python3`; fix template for future clones |
| Sudo / become fails | No sudo rights or password required | REMOTE VM `sudo -n true`; `sudo -l` | Grant intended administrative sudo through guest policy; use `--ask-become-pass` when needed |
| Vault decryption / secret assertion fails | Wrong Vault password, missing/short/reused values | `ansible-vault edit "$HOME/.config/zabbix-obs/vault.yml"` | Use three independent `openssl rand -base64 32` values and the documented `-e @... --ask-vault-pass` flags |
| Docker apt installation conflicts | Existing distro Docker/containerd or wrong OS | REMOTE VM `dpkg -l docker.io containerd docker-ce`; `cat /etc/os-release` | Use supported clean template; plan migration of existing workloads before removing conflicting packages |
| Container not starting / health check failing | Config, resource, permission or registry issue | REMOTE VM `cd /opt/zabbix-obs`; `sudo docker compose ps --all`; `sudo docker compose logs --tail 100`; `df -h`; `free -h` | Fix reported config/space/permission issue; rerun Ansible; preserve volumes and use operations readiness probes |
| Proxmox 403 / TLS / guest-agent timeout | Permissions, CA trust or unprepared template | Proxmox task log/console; WINDOWS CMD `tofu state list` | Correct scoped token privileges, trust the CA, or repair template agent; inspect existing VM before retrying |

Never set `StrictHostKeyChecking=no`, disable key permission checks, or delete
application volumes as a troubleshooting shortcut. Share only redacted logs.

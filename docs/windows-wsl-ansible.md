# First deployment: Windows CMD → OpenTofu → WSL → SSH → Ansible

This is the canonical first-run path. Commands assume a trusted checkout at
`C:\Projects\zabbix-obs`; substitute your actual checkout path consistently.
OpenTofu stays on Windows. Ansible runs from the same checkout mounted under
`/mnt/c`, in `deploy/ansible`. Debian 13 and login `debian` are the defaults.
Addresses in the examples (`192.0.2.10`) are documentation-only, never targets.

## A — Workstation prerequisites and a unique SSH key

**Purpose:** install tools and establish one VM access identity for this project.
**Prerequisites:** Windows with virtualization enabled, installation rights, and
a reviewed checkout. Read [prerequisites](prerequisites.md) for the VM template.

**WINDOWS CMD**, elevated only for installation:

```bat
where ssh
ssh -V
where tofu
tofu version
wsl --version
wsl --list --verbose
```

If tools are missing, **WINDOWS CMD as administrator**:

```bat
dism /Online /Add-Capability /CapabilityName:OpenSSH.Client~~~~0.0.1.0
winget install --id OpenTofu.Tofu --exact
wsl --install -d Ubuntu
wsl --update
wsl --set-default Ubuntu
```

Reboot if requested, launch Ubuntu once and create its Linux user. Reopen CMD
after installation so PATH is refreshed. `wsl --list --verbose` must show Ubuntu
using version 2; if needed run `wsl --set-version Ubuntu 2`. Docker Desktop is
optional, not a prerequisite for this VM workflow.

**WINDOWS CMD**, normal user:

```bat
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
ssh-keygen -t ed25519 -a 100 -f "%USERPROFILE%\.ssh\zabbix_obs_ed25519" -C "zabbix-obs-vm"
dir "%USERPROFILE%\.ssh\zabbix_obs_ed25519*"
type "%USERPROFILE%\.ssh\zabbix_obs_ed25519.pub"
```

Use a passphrase; it is entered interactively and never stored in scripts.
If that filename already exists, verify it belongs to this project rather than
overwriting it. Do not reuse a GitHub access key. The `.pub` file is public:
OpenTofu reads it into cloud-init `authorized_keys`. The file without `.pub` is
private: never commit it or copy it to the VM. Phase D copies this same private
key into WSL. **Check:** both files exist and the public line starts with
`ssh-ed25519`. If not, fix key creation before continuing to B.

## B — Provision from native Windows CMD

**Purpose:** clone a dedicated VM and set its public key, login and networking.
**Prerequisites:** prepared template with cloud-init, Python, sudo, SSH and
running qemu-guest-agent; actual node, datastore, bridge and API token from your
Proxmox administrator. See [OpenTofu details](opentofu.md) for permissions,
template settings, TLS and lifecycle. Do not guess IDs or storage names.

**WINDOWS CMD**:

```bat
cd /d "C:\Projects\zabbix-obs\deploy\opentofu\proxmox"
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
notepad credentials.auto.tfvars
```

In `terraform.tfvars`, replace endpoint, target node, template ID, free VM ID,
datastore and bridge. Confirm template boot disk/controller, CPU compatibility
and size (disks grow, not shrink). Keep `ssh_username = "debian"` for the default
template and `ssh_public_key_path = "~/.ssh/zabbix_obs_ed25519.pub"`. Native
Windows OpenTofu expands `~` to your Windows profile, not WSL. If supplying an
absolute Windows path, use forward slashes. Choose DHCP with a reservation or
your actual static CIDR, gateway and DNS. Keep trusted TLS enabled.

In the ignored `credentials.auto.tfvars`, use the following **HCL file content**
with your real token (entered in the editor, not the command history):

```hcl
proxmox_api_token = "automation@pve!zabbix-obs=YOUR_TOKEN_SECRET"
```

Save as the exact `.tfvars` filename, not `.tfvars.txt`. Store both filled files
on an access-controlled workstation; a provider environment variable
`PROXMOX_VE_API_TOKEN` injected by a credential manager is also supported.
State and saved plans are sensitive even when terminal output is redacted.

**WINDOWS CMD**, same directory:

```bat
tofu init
tofu fmt -check
tofu validate
tofu plan
tofu apply
tofu output
tofu output -raw ssh_username
tofu output guest_ipv4_addresses
tofu output guest_interfaces
```

**Check:** init/validate succeed; review the plan before answering the interactive
apply prompt. Expect one dedicated VM, not modifications to the source template.
If formatting fails after editing local inputs, run `tofu fmt` in the same CMD
directory, inspect the formatting changes, then repeat `tofu fmt -check`.
Map addresses to guest interfaces and select its reachable LAN IPv4, excluding
loopback and Docker bridges. Static addressing also produces `configured_ipv4`.
No inventory is generated. Record the selected IP and output username for E/F.

**PROXMOX WEB INTERFACE:** inspect the new VM's Summary, Cloud-Init and console.
Verify its IP and that cloud-init completed. From the **REMOTE VM console**:

```bash
cloud-init status --wait
ip -br address
systemctl is-active ssh qemu-guest-agent
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Record the host fingerprint over this trusted console for phase E. If no guest
addresses appear, inspect the guest agent and DHCP/network configuration through
the console. A provider timeout may leave an existing VM: inspect `tofu state list`
and Proxmox tasks before retrying; do not blindly create another VM. Resolve API
permission/TLS errors using [troubleshooting](troubleshooting.md). Continue to C
when the intended VM is reachable and cloud-init is complete.

## C — Enter WSL directly from the Ansible directory

**Purpose:** use the same Windows checkout with the Linux Ansible control node.
**Prerequisites:** Ubuntu is your default WSL distribution; the VM is provisioned.

**WINDOWS CMD**, exactly this transition:

```bat
cd /d "C:\Projects\zabbix-obs\deploy\ansible"
wsl
```

**WSL / UBUNTU BASH**:

```bash
pwd
whoami
ls -la
ansible --version
```

Expected `pwd`: `/mnt/c/Projects/zabbix-obs/deploy/ansible` (case may reflect the
actual Windows directory). If WSL starts elsewhere:

```bash
cd /mnt/c/Projects/zabbix-obs/deploy/ansible
```

If Ansible is not installed, **WSL / UBUNTU BASH**, Ubuntu 24.04 or newer:

```bash
sudo apt update
sudo apt install -y pipx python3-venv openssh-client openssl
pipx install 'ansible-core==2.20.6'
export PATH="$HOME/.local/bin:$PATH"
ansible --version
```

Ansible core 2.20 needs Python 3.12+. Use a current Ubuntu distribution if
installation reports an unsupported Python. Windows and Linux usernames need
not match. `whoami` is the Linux operator, not the guest login user. **Next:** D.

## D — Copy the matching private key into WSL

**Purpose:** provide Linux file permissions and the identity cloud-init trusts.
**Prerequisites:** phase A's Windows key; trusted WSL user home.
**WSL / UBUNTU BASH**, from `deploy/ansible`:

```bash
WIN_HOME="$(wslpath "$(cmd.exe /C 'echo %USERPROFILE%' | tr -d '\r')")"
echo "$WIN_HOME"
KEY_NAME="zabbix_obs_ed25519"
install -d -m 700 "$HOME/.ssh"
ls -l "$WIN_HOME/.ssh/$KEY_NAME"
install -m 600 "$WIN_HOME/.ssh/$KEY_NAME" "$HOME/.ssh/$KEY_NAME"
ls -l "$HOME/.ssh/$KEY_NAME"
eval "$(ssh-agent -s)"
ssh-add "$HOME/.ssh/$KEY_NAME"
ssh-add -l
```

**Check:** the destination is mode `-rw-------`; the agent lists the expected
ED25519 identity. `C:\...` is `/mnt/c/...` in WSL; `%USERPROFILE%` and `$HOME`
are separate homes. NTFS-mounted files can appear broadly readable and cause
`UNPROTECTED PRIVATE KEY FILE`. Using native Linux `~/.ssh` fixes permissions
without weakening SSH. If the source is missing, inspect `WIN_HOME` and the
Windows key name; do not generate a different WSL key to mask the mismatch.
Enter passphrases only at prompts. Each new agent session may need `ssh-add`.
**Next:** E.

## E — Establish verified SSH before Ansible

**Purpose:** verify routing, login identity and the server host key independently.
**Prerequisites:** actual VM address/username and console fingerprint from B.
**WSL / UBUNTU BASH** (replace documentation values):

```bash
VM_IP=192.0.2.10
VM_USER=debian
ssh -o IdentitiesOnly=yes -i "$HOME/.ssh/$KEY_NAME" "$VM_USER@$VM_IP"
```

Compare the displayed host-key fingerprint with the trusted console record
before accepting it. If SSH negotiates a different host-key algorithm, get that
algorithm's public-key fingerprint from the console. `ssh-keyscan` alone does
not establish trust. Inside the **REMOTE VM**:

```bash
whoami
cloud-init status --wait
systemctl is-active ssh
python3 --version
sudo -n true
exit
```

**Check:** guest login matches OpenTofu output, cloud-init is done, Python exists
and sudo works. If sudo requires a password, arrange one via your guest policy
and append `--ask-become-pass` to Ansible privileged commands; never put it in
inventory. For key denial use `ssh -vvv -o IdentitiesOnly=yes -i
"$HOME/.ssh/$KEY_NAME" "$VM_USER@$VM_IP"` and compare the offered key with
cloud-init. For timeouts check route, bridge/VLAN, firewall and guest IP in the
console. Full diagnostics are in H. **Do not continue until normal SSH works.**

## F — Configure, validate and deploy Ansible

**Purpose:** converge the OS, Docker and application using local inventory and
encrypted secrets. **Prerequisites:** working verified SSH, sudo, remote Python.
**WSL / UBUNTU BASH**, still `deploy/ansible`:

```bash
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible --version
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.ini.example inventory/hosts.ini
cp inventory/vars.yml.example inventory/vars.yml
nano inventory/hosts.ini
nano inventory/vars.yml
```

Use B's actual IP in `ansible_host` and username in `ansible_user`. Keep the
`observability` group. The playbook is `playbooks/site.yml`; roles are in `roles/`
and `ansible.cfg` explicitly sets that path. Leave bindings on loopback for now.
There is no requirement to create a root `.env`; Ansible renders the guest's
root-only `/opt/zabbix-obs/.env` from variables.

**Important `/mnt/c` caveat:** Ansible may refuse automatic config discovery in
a world-writable Windows mount. `ansible --version` must report this checkout's
`deploy/ansible/ansible.cfg` after the explicit export above. Use it only after
reviewing the config and confirming that the directory is controlled by trusted
operators. Explicit selection does not make an untrusted directory safe. If
Windows ACLs/trust cannot be established, use a separate trusted checkout of
the **whole repository** on the native WSL filesystem, preserve the same layout,
and reset `ANSIBLE_CONFIG` from its `deploy/ansible` directory. This is a fallback,
not the standard path. Keep keys and secrets outside both checkouts.

Create secrets outside the Git tree, **WSL / UBUNTU BASH**:

```bash
install -d -m 700 "$HOME/.config/zabbix-obs"
openssl rand -base64 32
openssl rand -base64 32
openssl rand -base64 32
umask 077
ansible-vault create "$HOME/.config/zabbix-obs/vault.yml"
```

Use `secrets.yml.example` as the schema: enter the three distinct generated values
under `zabbix_db_password`, `grafana_admin_password`, `grafana_secret_key`.
Protect the Vault password in your password manager, not the checkout or a
command argument. Avoid capturing generated values in shared terminal logs.
Use `ansible-vault edit` for subsequent changes, not `create` again.

**WSL / UBUNTU BASH**, ordered validation and deployment:

```bash
ansible-inventory -i inventory/hosts.ini --list
ansible all -i inventory/hosts.ini \
  --private-key "$HOME/.ssh/$KEY_NAME" -m ping
ansible-playbook -i inventory/hosts.ini \
  --private-key "$HOME/.ssh/$KEY_NAME" \
  -e @inventory/vars.yml -e @"$HOME/.config/zabbix-obs/vault.yml" \
  --ask-vault-pass --syntax-check playbooks/site.yml
ansible-playbook -i inventory/hosts.ini \
  --private-key "$HOME/.ssh/$KEY_NAME" \
  -e @inventory/vars.yml -e @"$HOME/.config/zabbix-obs/vault.yml" \
  --ask-vault-pass playbooks/site.yml
```

**Check:** inventory contains the intended guest only; ping reports `SUCCESS`
and `"ping": "pong"`. This is an SSH/Python Ansible module, not ICMP.
Syntax check names the playbook without errors. The deployment recap must have
`failed=0 unreachable=0`; startup may take several minutes. The role validates
secrets, installs Docker from its signed official repository, deploys the stack,
waits for Compose health and probes internal telemetry readiness. If a task
fails, diagnose it before rerunning; initial `--check` is not a substitute for
deployment because Docker and remote files do not exist yet. **Next:** G.

## G — Verify internally and complete first-run setup

**Purpose:** verify the actual runtime before external access.
**Prerequisites:** successful Ansible recap. **WSL / UBUNTU BASH:** repeat the
deployment command from F. Converged resources should report no unexpected
changes; image pulls, completed init jobs and requested OS upgrades can report
changes. Investigate persistent configuration churn.

**WSL / UBUNTU BASH**, SSH to the guest, then **REMOTE VM**:

```bash
sudo docker version
sudo docker compose version
cd /opt/zabbix-obs
sudo docker compose config --quiet
sudo docker compose ps --all
curl -fsS http://127.0.0.1:8080/ -o /dev/null
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:16686/ -o /dev/null
sudo docker compose exec -T zabbix-server wget -qO- http://loki:3100/ready
sudo docker compose exec -T zabbix-server wget -qO- http://otel-collector:13133/
sudo docker compose exec -T zabbix-server wget -qO- http://jaeger:13133/status
sudo docker compose logs --tail 100
sudo docker volume inspect zabbix-obs-postgres zabbix-obs-grafana zabbix-obs-loki zabbix-obs-jaeger-v2
sudo docker inspect --format '{{json .HostConfig.PortBindings}}' zabbix-obs-web zabbix-obs-grafana zabbix-obs-jaeger zabbix-obs-otel zabbix-obs-server
exit
```

Use configured project names/ports if overridden. Check that bindings are
`127.0.0.1`, init containers exited 0, other services are running/healthy, and
named data mounts exist. Do not print rendered Compose configuration without
`--quiet` into tickets: it contains secrets.

**WINDOWS CMD**, another window, replace IP/user with your actual values:

```bat
ssh -N -o ExitOnForwardFailure=yes -o IdentitiesOnly=yes -i "%USERPROFILE%\.ssh\zabbix_obs_ed25519" -L 8080:127.0.0.1:8080 -L 3000:127.0.0.1:3000 -L 16686:127.0.0.1:16686 debian@192.0.2.10
```

Windows has its own `known_hosts`; verify the same console fingerprint when
prompted here too. Keep the tunnel window open. In the Windows browser visit
`http://localhost:8080`, `http://localhost:3000`, `http://localhost:16686`.
If a local port is occupied, use a free left-side port (for example
`-L 18080:127.0.0.1:8080`) and the corresponding browser URL.

1. Zabbix: sign in as `Admin` / `zabbix`, immediately change the password and
   create named administrators and least-privilege viewers.
2. Grafana: use the Vault admin password; complete [Grafana setup](grafana.md).
   Environment admin passwords initialize new databases, not existing accounts.
3. Register monitored hosts, configure encrypted agents and test both alert and
   recovery notification delivery using [monitoring plan](monitoring-plan.md).
4. Verify a test log and trace through OTLP; check Loki/Jaeger data sources in
   Grafana. Establish [backup and restore](backup-restore.md) before production.

**Recovery:** use [operations](operations.md) and H for failed health checks;
never remove volumes to solve startup errors. **Next:** optional
[manual Cloudflare Tunnel](cloudflare-tunnel.md), then [daily deployment](daily-deployment.md).
These are operator acceptance steps, not a claim that a real VM was tested by
the project review. See [validation report](validation-report.md).

## H — Troubleshooting

The mandatory [symptom → cause → diagnostic → fix table](troubleshooting.md)
covers every phase above. Return to the failed phase only after its checks
pass; do not disable host-key checking or SSH permission checks.

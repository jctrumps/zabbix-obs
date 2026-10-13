# SSH identity reference

The project identity is **`zabbix_obs_ed25519`**. The canonical
[Windows key creation and WSL copy](windows-wsl-ansible.md) are phases A and D.

| Location | Purpose |
|---|---|
| `%USERPROFILE%\.ssh\zabbix_obs_ed25519.pub` | Windows public key read by native OpenTofu/cloud-init |
| `%USERPROFILE%\.ssh\zabbix_obs_ed25519` | Windows private key, never uploaded to the VM |
| `$HOME/.ssh/zabbix_obs_ed25519` in WSL | Matching copied private key, mode 600, directory mode 700 |
| Guest user's `~/.ssh/authorized_keys` | Public key installed by cloud-init |

Windows and WSL have distinct agents and `known_hosts` files. Verify host-key
fingerprints from a trusted Proxmox console in each client before accepting.
Passphrases go only into interactive prompts; `ssh-add` unlocks the key for
the current agent session. Never turn off host-key checking or strict key modes.

**WSL / UBUNTU BASH**, diagnostic commands (replace user/IP from real outputs):

```bash
ssh-add -l
ssh-keygen -y -f "$HOME/.ssh/zabbix_obs_ed25519" | ssh-keygen -lf -
ssh -vvv -o IdentitiesOnly=yes -i "$HOME/.ssh/zabbix_obs_ed25519" debian@192.0.2.10
```

Compare the derived public fingerprint with phase A's `.pub`. Logs can contain
environment details; redact before sharing. For an intentional VM replacement,
verify its new console fingerprint first, then remove only the obsolete local
entry with `ssh-keygen -R 192.0.2.10` and reconnect. Unexpected mismatches require
investigation. Key rotation requires adding/testing the new public key before
removing the old one; cloud-init changes alone are not a guaranteed rotation of
an already initialized guest. See [troubleshooting](troubleshooting.md).

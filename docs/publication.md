# Public repository preparation

The checked-in configuration is intended to be generic: UTC defaults, loopback bindings, documentation-only addresses (`192.0.2.0/24`), and placeholder credentials and Proxmox inputs. Service names, container paths, ports, upstream bootstrap credentials, and provider checksums describe the example stack rather than a live deployment.

## Keep deployment information local

- Keep real Compose credentials in `.env`, which is ignored. Publish only `.env.example` with placeholders.
- Keep real Proxmox values in `terraform.tfvars`, which is ignored. OpenTofu state and saved plans can contain credentials and infrastructure identifiers; state, `.terraform/`, and the documented `tfplan` output are ignored. Keep `.terraform.lock.hcl` for reproducible provider selection.
- Copy Ansible example inventories to `deploy/ansible/local/inventories/` before entering real hostnames, IP addresses, usernames, domains, or secrets. The `local/` directory is ignored. Encrypt local credentials with Ansible Vault as described in the deployment guide.
- Keep private keys, vault password files, database dumps, backup archives, and telemetry exports outside the public source tree. Common filenames and backup formats are also ignored.
- Review custom dashboards, Zabbix templates, screenshots, and documentation for hostnames, serial numbers, MAC addresses, tenant IDs, notification recipients, and actual telemetry before adding them.

Ignore rules prevent accidental additions of matching untracked files. They do not sanitize file contents or remove files already tracked by Git. Do not force-add local deployment files.

## Review the first revision

After initializing Git and staging the intended source files, inspect:

```bash
git status --short
git diff --cached --stat
git diff --cached
git ls-files
```

Run a secret scanner over the working tree before the first commit and over Git history before publishing. For example, with Gitleaks installed:

```bash
gitleaks dir . --redact
# After creating commits:
gitleaks git . --redact
```

Also manually review names, addresses, domains, paths, and screenshots: secret scanners do not reliably detect infrastructure identifiers or personal information. If a credential was ever committed, rotate it and remove it from history before publishing; deleting it in a later commit is insufficient.

Git commits expose author and committer names and email addresses. Choose the identity you want public and use your GitHub-provided noreply email if you want to conceal your personal email. Review commit metadata before pushing:

```bash
git log --format=fuller
```

Enable GitHub secret scanning and push protection for the public repository. Repeat the staged-file review for future changes.

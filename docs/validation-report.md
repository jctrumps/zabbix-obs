# Validation report

Review date: 2026-10-12. Scope: local repository alignment with the supplied
Infrastructure as Code Project Generator standard. No Proxmox apply, SSH to
operator infrastructure, Cloudflare change, Git commit or publication was run.

## Review findings and implementation

| Standard area | Finding / correction |
|---|---|
| Primary workstation workflow | Replaced the Docker Desktop-focused primary guide with native Windows CMD OpenTofu, then CMD into `deploy/ansible` and WSL in the mounted checkout |
| Cloud-init handoff | Added public-key path, non-root user, DHCP/static networking, DNS, guest-agent/boot settings, metadata and address/user outputs |
| Ansible onboarding | Added one `.example` inventory, explicit key/config/roles paths, outside-checkout Vault, SSH fingerprint checks, syntax/ping/deployment commands and troubleshooting |
| Guest convergence | Official Docker apt repository for Debian 13/Ubuntu 24.04, opt-in OS/package upgrades, secret-safe rendering, config-triggered recreation and readiness/status tasks |
| Maintained trace component | Replaced Jaeger 1 with pinned Jaeger 2.15.0, explicit config and separate `jaeger-v2` data volume; no automatic historical-data migration |
| Operator documentation | Added first-run/daily/native Linux, prerequisite/SSH/OpenTofu/Ansible references, manual-only Cloudflare, operations, guest-native backup/restore and publication guides |
| Publication | Added original-source MIT license, contribution/editor/line-ending conventions, stronger ignores, local audit and source-only ZIP helper |
| Responsibility boundaries | Zabbix still owns infrastructure alerting; no second alert engine, tunnel automation or unrelated service was added |

The existing `deploy/` structure was retained and all commands use it. The
reusable prompt itself was not edited. Blank project-specific fields were resolved
from the repository: `zabbix-obs`, Proxmox VM, Debian 13 default, Docker Compose,
4 vCPU/8 GiB/100 GiB, optional manually configured external access.

## Public convention review actually performed

GitHub CLI was installed but unauthenticated. Public HTTPS access succeeded;
the profile and these public README files were reviewed:

- <https://github.com/jctrumps/ollama-ai> — OpenTofu → Ansible → Compose separation,
  `/opt` application path and dedicated WSL SSH identity.
- <https://github.com/jctrumps/proxmox-debian13> — Debian 13 template, `debian`
  cloud-init user, guest-agent preparation and clean cloned SSH identity.

No private repositories were accessed and no environment-specific values were
copied. Provider 0.111.1's VM schema and Jaeger 2.15.0's Badger/query/health
configuration sources were consulted for implementation details.

## Local checks executed

| Check | Result |
|---|---|
| Native Windows OpenTofu 1.12.0: `tofu init -backend=false -input=false` | Passed; reused/installed locked `bpg/proxmox` 0.111.1; no backend or live infrastructure operation |
| `tofu fmt -check` and `tofu validate` | Passed for the updated module |
| Example tfvars formatting via `tofu fmt -` and comparison | Passed after fixing alignment; copied example will meet the first-run formatting gate |
| Docker Compose 5.1.2: `docker compose --env-file .env.example config --quiet` | Passed with tracked placeholder values; no containers started |
| Jaeger 2.15.0 image manifest | Registry manifest exists, including linux/amd64; image execution was not tested |
| WSL Ansible core 2.20.6, community.docker 4.8.9 | Example inventory parsed; `ansible-playbook -i inventory/hosts.ini.example --syntax-check playbooks/site.yml` passed with explicit `ANSIBLE_CONFIG` |
| Ansible lint 26.10.0 (isolated tool environment, core 2.21.5) | Explicit playbook, both task files, defaults and collection requirements: 0 failures, 0 warnings |
| `bash -n scripts/check-structure.sh` and structure check | Passed; helper fixed to LF line endings |
| `python scripts/validate-source.py` on Windows and `python3` under WSL | Passed local Markdown file links, allowed source paths, ignore probes and limited credential signatures |
| Environment/template/Compose consistency | Identical environment keys and image defaults; deliberately pinned images |
| Documented Bash fences | Passed `bash -n` under WSL; commands were not executed against targets |
| `git diff --check`, status and implementation diff review | Passed whitespace check; local changes remain uncommitted |

OpenTofu initialization emitted an **expired provider signing-key warning** for
the locked provider. Installation and checksum validation succeeded in this
OpenTofu version, but the warning says future versions may reject that signature.
No signature check was disabled. Review a provider release with renewed signing
metadata before upgrading tooling; do not bypass verification.

The publication helper creates `dist/zabbix-obs-source.zip`, normalizes text to
LF, verifies its exact source membership and ZIP integrity, and prints SHA-256.
The archive includes this report and source/examples, not `.git`, local inventories,
state/plans, provider downloads, private keys, secrets or runtime data.

## Reviewed only / still requires operator validation

- Windows CMD syntax and the identity chain were reviewed: Windows-generated
  `zabbix_obs_ed25519.pub` → cloud-init `debian` user → matching WSL private key →
  explicit local Ansible inventory. No actual workstation key was generated.
- No Proxmox API plan/apply, VM clone, SSH login, sudo/Python check, guest Docker
  installation or first/second-pass Ansible convergence was performed. Actual
  permissions, template firmware/disk/controller, agent and networking need the
  operator's environment. Ubuntu support is implemented but not guest-tested.
- Docker Desktop's Linux engine was stopped/unavailable. Runtime Jaeger 2 config
  validation, health probes (including Zabbix image `wget` availability), telemetry
  ingestion/query, Grafana plugin startup, migrations and this revision's restore
  procedure were not exercised. Static Compose success is not deployment success.
- The previous revision's runtime/recovery claims were not carried forward as
  evidence. Existing Jaeger 1 history requires an explicit operator migration/
  retention decision before upgrade.
- Cloudflare/DNS/Access configuration and public endpoint tests are manual and
  were not performed.
- Gitleaks was unavailable. Limited source signature checks and manual review
  passed; no dedicated credential scanner or full Git-history secret audit ran.
  Run the publication guide's scanner/history review before public release.

Begin operator acceptance at [windows-wsl-ansible.md](windows-wsl-ansible.md).
Reproduce the local checks using [CONTRIBUTING](../CONTRIBUTING.md); use
[public release](public-release.md) for the final publication audit.

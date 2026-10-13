# Public release

Publish source/examples only. Filled inventories, actual infrastructure details,
credentials, private keys, state/plans, backups and telemetry are not source.
`.gitignore` excludes standard local filenames; it cannot sanitize file content
or remove files already tracked. Even encrypted secrets are kept outside the tree.

## Audit — WINDOWS CMD, repository root

```bat
cd /d "C:\Projects\zabbix-obs"
git status --short
git diff --check
git diff
git diff --cached --stat
git diff --cached
git ls-files
git log --format=fuller
python scripts/validate-source.py
docker compose --env-file .env.example config --quiet
```

Inspect intended files before staging/committing. Review commit author/committer
names/emails before publication. Do not change Git identity automatically;
choose your public identity deliberately. Review screenshots, dashboards and
templates for real names, endpoints, topology, recipients and data as well as
credentials. New helper files must be included in review, not only tracked diffs.

If Gitleaks is installed, **WINDOWS CMD** (same syntax on native Linux):

```bat
gitleaks dir . --redact
gitleaks git . --redact
```

The first scans current files, the second Git history. Successful scans reduce
risk but do not prove no secret was ever committed/exposed. Rotate any exposed
credential and address history before publication. Enable GitHub secret scanning
and push protection when publishing manually.

## Source ZIP — WINDOWS CMD

Prerequisites: Python 3, Git and reviewed source changes. No deployment runs.

```bat
python scripts/build-release.py
```

The helper validates local Markdown links, environment/image consistency,
standard ignore behavior and selected secret patterns, then archives reviewed source candidates from Git's tracked and
nonignored untracked files under known source paths. It excludes deleted files,
`.git`, tool caches, local config/state/plans, archives and runtime data. It fails
on unexpected file types/paths so accidental new files require review. This is
a limited content audit, not a replacement for a dedicated secret scanner.

Output: `dist/zabbix-obs-source.zip`, with a top-level `zabbix-obs/` directory
and normalized LF text line endings for Linux/WSL use.
The script prints SHA-256 and verifies archive membership. Extract and inspect
before uploading. A ZIP contains the current source, not Git history or your
deployment data. If Git metadata is absent after extraction, initialize a local
Git repository before using these Git-based audit/packaging helpers.

Original IaC/docs are MIT licensed; upstream applications retain their respective
licenses. See [LICENSE](../LICENSE) and [CONTRIBUTING](../CONTRIBUTING.md).

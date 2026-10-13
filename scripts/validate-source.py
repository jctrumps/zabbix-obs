#!/usr/bin/env python3
"""Local-only source/link/ignore audit; no third-party Python dependencies."""

from pathlib import Path
import os
import re
import shutil
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {
    ".env.example", ".gitignore", ".gitattributes", ".editorconfig",
    "AGENTS.md", "README.md", "README-APPLY-OVERLAY.md", "CONTRIBUTING.md",
    "LICENSE", "MANIFEST.txt", "PROJECT_STATUS.md", "docker-compose.yml",
}
SOURCE_DIRS = {"docs", "deploy", "grafana", "loki", "otel", "jaeger", "scripts", "zabbix"}
SUFFIXES = {".md", ".tf", ".hcl", ".example", ".yml", ".yaml", ".cfg", ".sh", ".py", ".j2"}


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def source_files():
    names = git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
    files = []
    for name in sorted(set(names.decode().split("\0")) - {""}):
        path = ROOT / name
        if not path.exists():  # locally deleted tracked source
            continue
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Unsupported source entry: {name}")
        if not path.resolve().is_relative_to(ROOT):
            raise ValueError(f"Source outside checkout: {name}")
        parts = Path(name).parts
        if any(part in {".terraform", "local", "secrets", "data", "__pycache__"} for part in parts):
            raise ValueError(f"Local artifact included by Git: {name}")
        allowed = name in ROOT_FILES or (
            parts[0] in SOURCE_DIRS
            and (path.suffix in SUFFIXES or path.name == ".gitkeep")
            and not path.name.endswith((".auto.tfvars", ".tfstate", ".tfplan"))
            and not ({"inventory", "inventories"}.intersection(parts) and not path.name.endswith(".example"))
            and not (path.name in {"vault.yml", "vault.yaml", "secrets.yml", "secrets.yaml"})
        )
        if not allowed:
            raise ValueError(f"Review unexpected publication candidate: {name}")
        files.append(path)
    return files


def validate(files):
    errors = []
    environment = (ROOT / ".env.example").read_text(encoding="utf-8")
    template = (ROOT / "deploy/ansible/roles/zabbix-obs/templates/env.j2").read_text(encoding="utf-8")
    compose = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
    env_keys = set(re.findall(r"^(\w+)=", environment, re.MULTILINE))
    template_keys = set(re.findall(r"^(\w+)=", template, re.MULTILINE))
    if env_keys != template_keys:
        errors.append(f"Environment/template keys differ: {env_keys ^ template_keys}")
    for key, image in re.findall(r"^(\w+_IMAGE)=(.+)$", environment, re.MULTILINE):
        if image.endswith(":latest") or ":" not in image:
            errors.append(f"Unpinned image: {key}")
        if "${" + key + ":-" + image + "}" not in compose:
            errors.append(f"Compose image default differs from example: {key}")
        if not re.search(r"^" + key + r"=.*default\('" + re.escape(image) + r"'\)", template, re.MULTILINE):
            errors.append(f"Ansible image default differs from example: {key}")
    # Deliberately limited signatures; use a dedicated scanner for release/history.
    secret_patterns = [
        re.compile(r"-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----"),
        re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
        re.compile(r"\bAKIA[A-Z0-9]{16}\b"),
    ]
    for path in files:
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)
        for pattern in secret_patterns:
            if pattern.search(text):
                errors.append(f"Possible credential in {relative}")
        if path.suffix == ".md":
            if shutil.which("bash") and os.name != "nt":
                for block in re.findall(r"```bash\n(.*?)```", text, re.DOTALL):
                    check = subprocess.run(["bash", "-n"], input=block, text=True, capture_output=True)
                    if check.returncode:
                        errors.append(f"Invalid Bash block in {relative}: {check.stderr.strip()}")
            for target in re.findall(r"\[[^\]]*\]\(([^\s)]+)(?:\s+\"[^\"]*\")?\)", text):
                target = unquote(target.split("#", 1)[0])
                if not target or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                    continue
                if not (path.parent / target).exists():
                    errors.append(f"Broken local link in {relative}: {target}")
    ignored = [
        ".env", "deploy/opentofu/proxmox/terraform.tfvars",
        "deploy/opentofu/proxmox/credentials.auto.tfvars",
        "deploy/opentofu/proxmox/terraform.tfstate.backup",
        "deploy/opentofu/proxmox/tfplan", "deploy/opentofu/proxmox/change.tfplan",
        "deploy/ansible/inventory/hosts.ini", "deploy/ansible/inventory/vars.yml",
        "zabbix_obs_ed25519", "local/vault.yml", "dist/zabbix-obs-source.zip",
    ]
    for name in ignored:
        result = subprocess.run(["git", "-C", str(ROOT), "check-ignore", "--no-index", "-q", name])
        if result.returncode != 0:
            errors.append(f"Sensitive/generated path is not ignored: {name}")
    for name in [".env.example", "deploy/ansible/inventory/hosts.ini.example",
                 "deploy/opentofu/proxmox/.terraform.lock.hcl"]:
        result = subprocess.run(["git", "-C", str(ROOT), "check-ignore", "--no-index", "-q", name])
        if result.returncode != 1:
            errors.append(f"Required source is ignored: {name}")
    if shutil.which("tofu"):
        example = ROOT / "deploy/opentofu/proxmox/terraform.tfvars.example"
        check = subprocess.run(["tofu", "fmt", "-"],
                               input=example.read_text(encoding="utf-8"),
                               text=True, capture_output=True)
        if check.returncode or check.stdout != example.read_text(encoding="utf-8"):
            errors.append(f"tfvars example fails formatting:\n{check.stdout}{check.stderr}")
    if errors:
        raise ValueError("\n".join(errors))
    print(f"Source audit passed: {len(files)} files; local Markdown links, ignore rules, limited credential signatures.")
    print("Environment keys and pinned images agree across Compose, example and Ansible template.")
    if shutil.which("bash") and os.name != "nt":
        print("Documented Bash blocks passed bash -n (syntax only, not executed).")


if __name__ == "__main__":
    validate(source_files())

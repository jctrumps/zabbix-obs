# Windows deployment

The canonical workflow is now **Windows CMD → native OpenTofu → Proxmox VM →
Windows CMD → WSL Ubuntu → SSH → Ansible → Docker Compose**.

Start at [windows-wsl-ansible.md](windows-wsl-ansible.md), then use
[daily-deployment.md](daily-deployment.md) for repeat runs.

This replaces the older Docker Desktop/PowerShell walkthrough. Docker Desktop
is optional for local Compose validation; the always-on services run on the VM.

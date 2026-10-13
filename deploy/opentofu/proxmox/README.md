# Proxmox OpenTofu

Native Windows OpenTofu runs from this directory and clones a prepared
cloud-init template. It supplies the project public key, guest username and
network configuration. Connection outputs feed a manually filled local Ansible
inventory. The checked-in lockfile pins the provider.

- [First-run commands](../../../docs/windows-wsl-ansible.md)
- [Template prerequisites](../../../docs/prerequisites.md)
- [Inputs, state, TLS and lifecycle](../../../docs/opentofu.md)

Copy `terraform.tfvars.example` to the ignored `terraform.tfvars`. Keep token,
state and plans private. Review the plan and approve apply interactively.

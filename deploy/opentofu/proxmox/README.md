# Proxmox OpenTofu

This is a starting module for creating the `obs-01` VM. It intentionally expects an existing Debian/Ubuntu cloud-init template rather than encoding an OS image download into the module.

Workflow:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values.
tofu init
tofu validate
tofu plan
tofu apply
```

After the VM is provisioned, put its reachable address in the appropriate Ansible inventory and converge the host.

The provider constraint is recorded in `versions.tf`, and `.terraform.lock.hcl` pins the selected provider build and checksums. Commit lock-file updates only after reviewing and validating the provider upgrade. OpenTofu state may contain sensitive infrastructure details; use a protected remote backend with locking before multiple operators manage this deployment.

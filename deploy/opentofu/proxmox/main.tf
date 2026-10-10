resource "proxmox_virtual_environment_vm" "observability" {
  name      = var.vm_name
  node_name = var.target_node
  vm_id     = var.vm_id
  started   = true

  clone {
    vm_id = var.template_vm_id
    full  = var.clone_full
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = var.disk_size
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    datastore_id = var.storage_pool
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}

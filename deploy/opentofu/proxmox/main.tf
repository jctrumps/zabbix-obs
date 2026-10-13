resource "proxmox_virtual_environment_vm" "observability" {
  name          = var.vm_name
  description   = var.vm_description
  tags          = sort(var.vm_tags)
  node_name     = var.target_node
  vm_id         = var.vm_id
  started       = true
  on_boot       = var.on_boot
  boot_order    = [var.disk_interface]
  scsi_hardware = var.scsi_hardware

  agent {
    enabled = var.agent_enabled
    timeout = "5m"
    wait_for_ip {
      ipv4 = true
    }
  }

  clone {
    vm_id        = var.template_vm_id
    node_name    = var.template_node
    datastore_id = var.storage_pool
    full         = var.clone_full
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.storage_pool
    interface    = var.disk_interface
    size         = var.disk_size
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    datastore_id = var.storage_pool
    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }
    user_account {
      username = var.ssh_username
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
    }
    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
      }
    }
  }
}

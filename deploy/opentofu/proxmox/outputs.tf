output "vm_id" {
  value = proxmox_virtual_environment_vm.observability.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.observability.name
}

output "ssh_username" {
  value = var.ssh_username
}

output "configured_ipv4" {
  description = "Static address without CIDR, or null for DHCP."
  value       = var.ipv4_address == "dhcp" ? null : split("/", var.ipv4_address)[0]
}

output "guest_ipv4_addresses" {
  description = "Guest-agent addresses by interface. Select the reachable guest LAN address, not loopback or Docker bridges."
  value       = proxmox_virtual_environment_vm.observability.ipv4_addresses
}

output "guest_interfaces" {
  value = proxmox_virtual_environment_vm.observability.network_interface_names
}

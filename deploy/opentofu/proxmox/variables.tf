variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint, e.g. https://pve.example.com:8006/"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token in user@realm!tokenid=secret form"
}

variable "proxmox_insecure_tls" {
  type    = bool
  default = false
}

variable "target_node" {
  type        = string
  description = "Proxmox node on which to place the VM."
}

variable "vm_id" {
  type    = number
  default = 9010
}

variable "vm_name" {
  type    = string
  default = "obs-01"
}

variable "template_vm_id" {
  type        = number
  description = "Existing cloud-init/template VM ID to clone."
}

variable "clone_full" {
  type    = bool
  default = true
}

variable "cpu_cores" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type        = number
  default     = 100
  description = "VM disk size in GiB."

  validation {
    condition     = var.disk_size >= 32
    error_message = "disk_size must be at least 32 GiB."
  }
}

variable "storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

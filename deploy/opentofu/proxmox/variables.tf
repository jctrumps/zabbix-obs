variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint, e.g. https://pve.example.com:8006/"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  default     = null
  description = "Optional token; prefer provider PROXMOX_VE_API_TOKEN environment variable."
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
  default = "zabbix-obs"
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

variable "vm_description" {
  type    = string
  default = "Zabbix observability VM managed by OpenTofu"
}

variable "vm_tags" {
  type    = list(string)
  default = ["opentofu", "observability"]
}

variable "template_node" {
  type        = string
  default     = null
  description = "Source template node; null means target_node."
}

variable "cpu_type" {
  type    = string
  default = "x86-64-v2-AES"
}

variable "disk_interface" {
  type        = string
  default     = "scsi0"
  description = "Must match the existing template boot disk."
}

variable "scsi_hardware" {
  type    = string
  default = "virtio-scsi-pci"
}

variable "on_boot" {
  type    = bool
  default = true
}

variable "agent_enabled" {
  type        = bool
  default     = true
  description = "Requires qemu-guest-agent installed and running in the template."
}

variable "ipv4_address" {
  type        = string
  default     = "dhcp"
  description = "dhcp or an operator-supplied IPv4 CIDR."
  validation {
    condition     = var.ipv4_address == "dhcp" || can(cidrnetmask(var.ipv4_address))
    error_message = "Use dhcp or a valid IPv4 CIDR."
  }
}

variable "ipv4_gateway" {
  type    = string
  default = null
  validation {
    condition     = var.ipv4_address != "dhcp" || var.ipv4_gateway == null
    error_message = "Omit ipv4_gateway when using DHCP."
  }
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "ssh_username" {
  type    = string
  default = "debian"
  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*$", var.ssh_username)) && var.ssh_username != "root"
    error_message = "Choose a non-root Linux administrative username."
  }
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/zabbix_obs_ed25519.pub"
  description = "Public key only. On Windows ~ resolves to the native Windows user profile."
  validation {
    condition     = can(regex("^ssh-ed25519 [A-Za-z0-9+/=]+", trimspace(file(pathexpand(var.ssh_public_key_path)))))
    error_message = "Generate the project ED25519 key and provide the existing .pub file path."
  }
}

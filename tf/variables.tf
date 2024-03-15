variable "rg_name" {
  type        = string
  description = "ResourceGroup Name, where all Resources will be deployed."
}

variable "public_ip_range_allow_storage" {
  type        = string
  description = "Public IP Subnet allowed to access the Storage Accounts on their Public Endpoint"
}

variable "vm_ssh_key_file" {
  type        = string
  description = "Path to the Public RSA Key for SSH to VMs"
}

variable "ssl_cert_pfx_file"  {
  type        = string
  description = "Path to the PFX Certificate for SSL"
  default = null
}

variable "ssl_cert_pfx_passwd"  {
  type        = string
  description = "Password for the PFX Certificate for SSL"
  default = null
}
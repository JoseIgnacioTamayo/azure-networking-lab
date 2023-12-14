variable "rg_name" {
  type        = string
  description = "ResourceGroup Name, where all Resources will be deployed."
}

variable "public_ip_range_allow_storage" {
  type        = string
  description = "Public IP Subnet allowed to access the Storage Accounts on their Public Endpoint"
}
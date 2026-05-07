variable "admin_ssh_public_key" {
  description = "SSH public key for VM admin access"
  type        = string
  sensitive   = true # prevents value appearing in plan output
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH — your home IP"
  type        = string
  default     = "0.0.0.0/0" # overridden in production
}

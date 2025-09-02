variable "resource_group_name" {
  type        = string
  default     = "chay-rg"
}

variable "location" {
  type        = string
  default     = "East US"
}

variable "acr_name" {
  type        = string
  description = "name for acr"
  default     = "secureacr123"
}

variable "storage_account_name" {
  type        = string
  default     = "chayfunctionstorgae"
}

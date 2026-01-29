variable "name" {
  description = "Name of the resource pool"
  type        = string
}

variable "cluster_id" {
  description = "Parent cluster resource pool ID"
  type        = string
}

variable "cpu_reservation" {
  description = "CPU reservation in MHz"
  type        = number
  default     = 0
}

variable "memory_reservation" {
  description = "Memory reservation in MB"
  type        = number
  default     = 0
}

variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "enable_nat" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

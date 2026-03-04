variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
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

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "Task CPU"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Task memory"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired task count"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Min capacity"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Max capacity"
  type        = number
  default     = 6
}

variable "log_retention" {
  description = "Log retention days"
  type        = number
  default     = 30
}

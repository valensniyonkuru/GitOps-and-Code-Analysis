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
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = false # Cost saving for dev
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "Task CPU"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Task memory"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired task count"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Min capacity"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Max capacity"
  type        = number
  default     = 2
}

variable "log_retention" {
  description = "Log retention days"
  type        = number
  default     = 7
}

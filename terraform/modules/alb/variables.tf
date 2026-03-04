variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB"
  type        = list(string)
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

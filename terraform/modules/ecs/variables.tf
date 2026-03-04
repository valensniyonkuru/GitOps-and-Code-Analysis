variable "name" {
  description = "Name prefix"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "Task CPU units"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Task memory in MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired task count"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Min tasks for auto-scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Max tasks for auto-scaling"
  type        = number
  default     = 4
}

variable "assign_public_ip" {
  description = "Assign public IP to tasks"
  type        = bool
  default     = false
}

variable "log_retention" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

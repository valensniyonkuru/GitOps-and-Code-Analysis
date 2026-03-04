variable "name" {
  description = "Name prefix"
  type        = string
}

variable "log_group_arn" {
  description = "CloudWatch log group ARN"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

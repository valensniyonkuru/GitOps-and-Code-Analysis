output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "target_group_blue_arn" {
  value = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  value = aws_lb_target_group.green.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}

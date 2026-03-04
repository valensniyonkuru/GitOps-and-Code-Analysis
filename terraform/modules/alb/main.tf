# ALB Module

resource "aws_security_group" "this" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

# Ingress Rules
resource "aws_vpc_security_group_ingress_rule" "http_ipv4" {
  security_group_id = aws_security_group.this.id
  description       = "Allow HTTP from anywhere (IPv4)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.name}-alb-http-ipv4" })
}

resource "aws_vpc_security_group_ingress_rule" "http_ipv6" {
  security_group_id = aws_security_group.this.id
  description       = "Allow HTTP from anywhere (IPv6)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv6         = "::/0"

  tags = merge(var.tags, { Name = "${var.name}-alb-http-ipv6" })
}

resource "aws_vpc_security_group_ingress_rule" "https_ipv4" {
  security_group_id = aws_security_group.this.id
  description       = "Allow HTTPS from anywhere (IPv4)"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.name}-alb-https-ipv4" })
}

resource "aws_vpc_security_group_ingress_rule" "https_ipv6" {
  security_group_id = aws_security_group.this.id
  description       = "Allow HTTPS from anywhere (IPv6)"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv6         = "::/0"

  tags = merge(var.tags, { Name = "${var.name}-alb-https-ipv6" })
}

# Egress Rules
resource "aws_vpc_security_group_egress_rule" "allow_all_ipv4" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound traffic (IPv4)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${var.name}-alb-egress-ipv4" })
}

resource "aws_vpc_security_group_egress_rule" "allow_all_ipv6" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound traffic (IPv6)"
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"

  tags = merge(var.tags, { Name = "${var.name}-alb-egress-ipv6" })
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "blue" {
  name        = "${var.name}-tg-blue"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name}-tg-blue" })
}

resource "aws_lb_target_group" "green" {
  name        = "${var.name}-tg-green"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name}-tg-green" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

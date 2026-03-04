# Dev Environment - Main Configuration
# 
# Backend Configuration:
# Run scripts/setup-backend.sh first, then initialize with:
#   terraform init \
#     -backend-config="bucket=${TF_STATE_BUCKET}" \
#     -backend-config="key=secure-webapp/dev/terraform.tfstate" \
#     -backend-config="region=${TF_STATE_REGION}" \
#     -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
#     -backend-config="encrypt=true"

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote Backend - Configured via -backend-config flags
  # Values provided by scripts/get-backend-config.sh
  backend "s3" {
    # Configured dynamically - do not hardcode values
    # bucket         = <from TF_STATE_BUCKET>
    # region         = <from TF_STATE_REGION>
    # dynamodb_table = <from TF_LOCK_TABLE>
    # key            = secure-webapp/dev/terraform.tfstate
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
module "vpc" {
  source = "../../modules/vpc"

  name            = local.name
  vpc_cidr        = var.vpc_cidr
  azs             = local.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  enable_nat      = var.enable_nat
  tags            = local.tags
}

# ECR
module "ecr" {
  source = "../../modules/ecr"

  name        = var.project
  image_count = 10
  tags        = local.tags
}

# ALB
module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  container_port    = var.container_port
  health_check_path = "/"
  tags              = local.tags
}

# IAM
module "iam" {
  source = "../../modules/iam"

  name          = local.name
  log_group_arn = module.ecs.log_group_arn
  tags          = local.tags
}

# ECS
module "ecs" {
  source = "../../modules/ecs"

  name                  = local.name
  aws_region            = var.aws_region
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = var.enable_nat ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_blue_arn
  ecr_repository_url    = module.ecr.repository_url
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arn
  container_port        = var.container_port
  cpu                   = var.cpu
  memory                = var.memory
  desired_count         = var.desired_count
  min_capacity          = var.min_capacity
  max_capacity          = var.max_capacity
  assign_public_ip      = !var.enable_nat
  log_retention         = var.log_retention
  tags                  = local.tags
}

# Terraform Infrastructure - Secure CI/CD Pipeline

Modular Terraform configuration for ECS Fargate deployment.

## Structure

```
terraform/
├── modules/
│   ├── vpc/          # VPC, subnets, NAT
│   ├── ecr/          # Container registry
│   ├── alb/          # Load balancer
│   ├── iam/          # IAM roles
│   └── ecs/          # ECS cluster, service, tasks
└── environments/
    ├── dev/          # Development environment
    └── prod/         # Production environment
```

## Quick Start

```bash
# Deploy dev environment
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Deploy prod environment
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

## Environment Differences

| Setting       | Dev     | Prod    |
|---------------|---------|---------|
| NAT Gateway   | No      | Yes     |
| Tasks         | 1       | 2       |
| CPU           | 256     | 512     |
| Memory        | 512     | 1024    |
| Max Scale     | 2       | 6       |
| Log Retention | 7 days  | 30 days |

## Remote State (Recommended)

Uncomment backend config in `main.tf` and create S3 bucket:

```bash
aws s3 mb s3://your-tfstate-bucket --region us-east-1
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Outputs

After apply, get deployment values:

```bash
terraform output ecr_repository_url   # For docker push
terraform output ecs_cluster_name     # For Jenkins
terraform output ecs_service_name     # For Jenkins
terraform output application_url      # App URL
```

## Cleanup

```bash
terraform destroy
```

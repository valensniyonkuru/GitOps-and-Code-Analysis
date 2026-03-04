#!/bin/bash
# =============================================================================
# Terraform Infrastructure Deployment Script
# Deploys infrastructure with dynamic backend configuration
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
DEFAULT_REGION="eu-north-1"
DEFAULT_PROJECT="secure-webapp"
DEFAULT_ENVIRONMENT="dev"

# Parse arguments
ACTION="apply"
AUTO_APPROVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --environment|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --action|-a)
            ACTION="$2"
            shift 2
            ;;
        --auto-approve|-y)
            AUTO_APPROVE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --region         AWS region (default: ${DEFAULT_REGION})"
            echo "  --project        Project name (default: ${DEFAULT_PROJECT})"
            echo "  --environment    Environment: dev, prod (default: ${DEFAULT_ENVIRONMENT})"
            echo "  --action         Terraform action: plan, apply, destroy (default: apply)"
            echo "  --auto-approve   Skip approval prompts"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Set defaults
AWS_REGION="${AWS_REGION:-$DEFAULT_REGION}"
PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT}"
ENVIRONMENT="${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment. Must be 'dev' or 'prod'${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"

# Validate Terraform directory exists
if [ ! -d "$TF_DIR" ]; then
    echo -e "${RED}Error: Terraform directory not found: ${TF_DIR}${NC}"
    exit 1
fi

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to get AWS Account ID. Check AWS credentials.${NC}"
    exit 1
fi

# Calculate backend values
TF_STATE_BUCKET="${PROJECT_NAME}-tfstate-${AWS_ACCOUNT_ID}"
TF_STATE_REGION="${AWS_REGION}"
TF_LOCK_TABLE="${PROJECT_NAME}-tf-locks"
TF_STATE_KEY="${PROJECT_NAME}/${ENVIRONMENT}/terraform.tfstate"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Terraform Infrastructure Deployment${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Environment:    ${GREEN}${ENVIRONMENT}${NC}"
echo -e "AWS Account:    ${GREEN}${AWS_ACCOUNT_ID}${NC}"
echo -e "AWS Region:     ${GREEN}${AWS_REGION}${NC}"
echo -e "State Bucket:   ${GREEN}${TF_STATE_BUCKET}${NC}"
echo -e "State Key:      ${GREEN}${TF_STATE_KEY}${NC}"
echo -e "Lock Table:     ${GREEN}${TF_LOCK_TABLE}${NC}"
echo -e "Action:         ${GREEN}${ACTION}${NC}"
echo ""

# Check if backend exists
echo -e "${YELLOW}Checking backend infrastructure...${NC}"
if ! aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
    echo -e "${RED}Error: Backend bucket does not exist.${NC}"
    echo -e "${YELLOW}Run 'scripts/setup-backend.sh' first to create the backend.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Backend bucket exists${NC}"

# Change to Terraform directory
cd "$TF_DIR"

# Initialize Terraform with dynamic backend
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init \
    -backend-config="bucket=${TF_STATE_BUCKET}" \
    -backend-config="key=${TF_STATE_KEY}" \
    -backend-config="region=${TF_STATE_REGION}" \
    -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
    -backend-config="encrypt=true" \
    -reconfigure

echo -e "${GREEN}✓ Terraform initialized${NC}"

# Execute action
case $ACTION in
    plan)
        echo -e "${YELLOW}Running Terraform plan...${NC}"
        terraform plan \
            -var="aws_region=${AWS_REGION}" \
            -var="project=${PROJECT_NAME}" \
            -var="environment=${ENVIRONMENT}"
        ;;
    apply)
        echo -e "${YELLOW}Running Terraform apply...${NC}"
        if [ "$AUTO_APPROVE" = true ]; then
            terraform apply \
                -var="aws_region=${AWS_REGION}" \
                -var="project=${PROJECT_NAME}" \
                -var="environment=${ENVIRONMENT}" \
                -auto-approve
        else
            terraform apply \
                -var="aws_region=${AWS_REGION}" \
                -var="project=${PROJECT_NAME}" \
                -var="environment=${ENVIRONMENT}"
        fi
        
        echo ""
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}Infrastructure deployed successfully!${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        echo -e "${BLUE}Outputs:${NC}"
        terraform output
        ;;
    destroy)
        echo -e "${RED}Running Terraform destroy...${NC}"
        if [ "$AUTO_APPROVE" = true ]; then
            terraform destroy \
                -var="aws_region=${AWS_REGION}" \
                -var="project=${PROJECT_NAME}" \
                -var="environment=${ENVIRONMENT}" \
                -auto-approve
        else
            terraform destroy \
                -var="aws_region=${AWS_REGION}" \
                -var="project=${PROJECT_NAME}" \
                -var="environment=${ENVIRONMENT}"
        fi
        echo -e "${GREEN}Infrastructure destroyed.${NC}"
        ;;
    output)
        echo -e "${BLUE}Terraform outputs:${NC}"
        terraform output
        ;;
    *)
        echo -e "${RED}Error: Invalid action '${ACTION}'. Use plan, apply, destroy, or output.${NC}"
        exit 1
        ;;
esac

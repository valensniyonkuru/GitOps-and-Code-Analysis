#!/bin/bash
# =============================================================================
# Terraform Backend Setup Script
# Creates S3 bucket and DynamoDB table for remote state management
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_REGION="eu-north-1"
DEFAULT_PROJECT="secure-webapp"

# Parse arguments
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
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --region    AWS region (default: ${DEFAULT_REGION})"
            echo "  --project   Project name (default: ${DEFAULT_PROJECT})"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Set defaults if not provided
AWS_REGION="${AWS_REGION:-$DEFAULT_REGION}"
PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to get AWS Account ID. Please configure AWS credentials.${NC}"
    exit 1
fi

# Generate unique names
BUCKET_NAME="${PROJECT_NAME}-tfstate-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="${PROJECT_NAME}-tf-locks"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Terraform Backend Setup${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "AWS Account ID: ${GREEN}${AWS_ACCOUNT_ID}${NC}"
echo -e "AWS Region:     ${GREEN}${AWS_REGION}${NC}"
echo -e "Project Name:   ${GREEN}${PROJECT_NAME}${NC}"
echo -e "S3 Bucket:      ${GREEN}${BUCKET_NAME}${NC}"
echo -e "DynamoDB Table: ${GREEN}${DYNAMODB_TABLE}${NC}"
echo ""

# Function to check if S3 bucket exists
bucket_exists() {
    aws s3api head-bucket --bucket "$1" 2>/dev/null
    return $?
}

# Function to check if DynamoDB table exists
table_exists() {
    aws dynamodb describe-table --table-name "$1" --region "$AWS_REGION" 2>/dev/null
    return $?
}

# Create S3 bucket
echo -e "${YELLOW}Creating S3 bucket for Terraform state...${NC}"
if bucket_exists "$BUCKET_NAME"; then
    echo -e "${GREEN}✓ S3 bucket already exists: ${BUCKET_NAME}${NC}"
else
    # Create bucket (different command for us-east-1)
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    
    echo -e "${GREEN}✓ S3 bucket created: ${BUCKET_NAME}${NC}"
fi

# Enable versioning
echo -e "${YELLOW}Enabling versioning on S3 bucket...${NC}"
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable server-side encryption
echo -e "${YELLOW}Enabling encryption on S3 bucket...${NC}"
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Block public access
echo -e "${YELLOW}Blocking public access on S3 bucket...${NC}"
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'
echo -e "${GREEN}✓ Public access blocked${NC}"

# Create DynamoDB table
echo -e "${YELLOW}Creating DynamoDB table for state locking...${NC}"
if table_exists "$DYNAMODB_TABLE"; then
    echo -e "${GREEN}✓ DynamoDB table already exists: ${DYNAMODB_TABLE}${NC}"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=ManagedBy,Value=Script
    
    # Wait for table to be active
    echo -e "${YELLOW}Waiting for DynamoDB table to be active...${NC}"
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    echo -e "${GREEN}✓ DynamoDB table created: ${DYNAMODB_TABLE}${NC}"
fi

# Create output file for CI/CD
OUTPUT_DIR="$(dirname "$0")/../.terraform-backend"
mkdir -p "$OUTPUT_DIR"

cat > "${OUTPUT_DIR}/backend-config.env" << EOF
# Terraform Backend Configuration
# Generated by setup-backend.sh on $(date)
TF_STATE_BUCKET=${BUCKET_NAME}
TF_STATE_REGION=${AWS_REGION}
TF_LOCK_TABLE=${DYNAMODB_TABLE}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
PROJECT_NAME=${PROJECT_NAME}
EOF

cat > "${OUTPUT_DIR}/backend.hcl" << EOF
# Terraform Backend Configuration
# Generated by setup-backend.sh on $(date)
bucket         = "${BUCKET_NAME}"
region         = "${AWS_REGION}"
dynamodb_table = "${DYNAMODB_TABLE}"
encrypt        = true
EOF

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Backend setup complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Configuration files created:"
echo -e "  ${GREEN}${OUTPUT_DIR}/backend-config.env${NC} - Environment variables"
echo -e "  ${GREEN}${OUTPUT_DIR}/backend.hcl${NC} - Terraform backend config"
echo ""
echo -e "To use in Terraform:"
echo -e "  ${YELLOW}terraform init -backend-config=${OUTPUT_DIR}/backend.hcl -backend-config=\"key=secure-webapp/dev/terraform.tfstate\"${NC}"
echo ""
echo -e "To use in CI/CD:"
echo -e "  ${YELLOW}source ${OUTPUT_DIR}/backend-config.env${NC}"
echo ""
echo -e "${BLUE}Backend Values:${NC}"
echo "TF_STATE_BUCKET=${BUCKET_NAME}"
echo "TF_STATE_REGION=${AWS_REGION}"
echo "TF_LOCK_TABLE=${DYNAMODB_TABLE}"

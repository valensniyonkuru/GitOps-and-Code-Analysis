#!/bin/bash
# =============================================================================
# Terraform Backend Destroy Script
# Removes S3 bucket and DynamoDB table (USE WITH CAUTION!)
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
DEFAULT_REGION="eu-north-1"
DEFAULT_PROJECT="secure-webapp"

# Parse arguments
FORCE=false
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
        --force)
            FORCE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --region    AWS region (default: ${DEFAULT_REGION})"
            echo "  --project   Project name (default: ${DEFAULT_PROJECT})"
            echo "  --force     Skip confirmation prompt"
            echo "  --help      Show this help message"
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

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to get AWS Account ID${NC}"
    exit 1
fi

BUCKET_NAME="${PROJECT_NAME}-tfstate-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="${PROJECT_NAME}-tf-locks"

echo -e "${RED}============================================${NC}"
echo -e "${RED}WARNING: This will destroy the Terraform backend!${NC}"
echo -e "${RED}============================================${NC}"
echo ""
echo -e "S3 Bucket:      ${YELLOW}${BUCKET_NAME}${NC}"
echo -e "DynamoDB Table: ${YELLOW}${DYNAMODB_TABLE}${NC}"
echo ""
echo -e "${RED}All Terraform state files will be PERMANENTLY DELETED!${NC}"
echo ""

if [ "$FORCE" != true ]; then
    read -p "Type 'destroy' to confirm: " CONFIRM
    if [ "$CONFIRM" != "destroy" ]; then
        echo -e "${GREEN}Aborted.${NC}"
        exit 0
    fi
fi

# Delete all objects and versions from S3
echo -e "${YELLOW}Deleting all objects from S3 bucket...${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    # Delete all versions
    aws s3api list-object-versions --bucket "$BUCKET_NAME" \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
        jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' 2>/dev/null | \
        while read -r args; do
            if [ -n "$args" ]; then
                eval aws s3api delete-object --bucket "$BUCKET_NAME" $args
            fi
        done

    # Delete all delete markers
    aws s3api list-object-versions --bucket "$BUCKET_NAME" \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
        jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' 2>/dev/null | \
        while read -r args; do
            if [ -n "$args" ]; then
                eval aws s3api delete-object --bucket "$BUCKET_NAME" $args
            fi
        done

    # Delete bucket
    aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
    echo -e "${GREEN}✓ S3 bucket deleted${NC}"
else
    echo -e "${YELLOW}S3 bucket does not exist${NC}"
fi

# Delete DynamoDB table
echo -e "${YELLOW}Deleting DynamoDB table...${NC}"
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" 2>/dev/null; then
    aws dynamodb delete-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    echo -e "${GREEN}✓ DynamoDB table deleted${NC}"
else
    echo -e "${YELLOW}DynamoDB table does not exist${NC}"
fi

# Remove local config files
OUTPUT_DIR="$(dirname "$0")/../.terraform-backend"
if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
    echo -e "${GREEN}✓ Local config files removed${NC}"
fi

echo ""
echo -e "${GREEN}Backend destroyed successfully.${NC}"

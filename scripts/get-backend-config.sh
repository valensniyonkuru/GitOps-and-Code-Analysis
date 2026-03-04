#!/bin/bash
# =============================================================================
# Get Terraform Backend Configuration
# Retrieves existing backend config or outputs values for CI/CD
# =============================================================================

set -e

# Default values
DEFAULT_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
DEFAULT_PROJECT="secure-webapp"

# Parse arguments
OUTPUT_FORMAT="env"
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
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --region    AWS region (default: ${DEFAULT_REGION})"
            echo "  --project   Project name (default: ${DEFAULT_PROJECT})"
            echo "  --format    Output format: env, json, hcl (default: env)"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
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
    echo "Error: Unable to get AWS Account ID" >&2
    exit 1
fi

# Generate names based on convention
BUCKET_NAME="${PROJECT_NAME}-tfstate-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="${PROJECT_NAME}-tf-locks"

# Verify bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Error: Backend bucket does not exist. Run setup-backend.sh first." >&2
    exit 1
fi

# Output based on format
case $OUTPUT_FORMAT in
    env)
        echo "TF_STATE_BUCKET=${BUCKET_NAME}"
        echo "TF_STATE_REGION=${AWS_REGION}"
        echo "TF_LOCK_TABLE=${DYNAMODB_TABLE}"
        echo "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
        ;;
    json)
        cat << EOF
{
    "bucket": "${BUCKET_NAME}",
    "region": "${AWS_REGION}",
    "dynamodb_table": "${DYNAMODB_TABLE}",
    "encrypt": true,
    "aws_account_id": "${AWS_ACCOUNT_ID}"
}
EOF
        ;;
    hcl)
        cat << EOF
bucket         = "${BUCKET_NAME}"
region         = "${AWS_REGION}"
dynamodb_table = "${DYNAMODB_TABLE}"
encrypt        = true
EOF
        ;;
    *)
        echo "Error: Unknown format: ${OUTPUT_FORMAT}" >&2
        exit 1
        ;;
esac

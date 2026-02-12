#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infrastructure"
ENV_FILE="$ROOT_DIR/frontend/.env.local"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is not installed or not in PATH"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required by this script. Install jq and retry."
  exit 1
fi

tf_outputs_json="$(terraform -chdir="$TF_DIR" output -json)"

required_outputs=(
  frontend_admin_api_base_url
  frontend_public_api_base_url
  frontend_cognito_user_pool_id
  frontend_cognito_client_id
  frontend_aws_region
)

for output_name in "${required_outputs[@]}"; do
  if ! echo "$tf_outputs_json" | jq -e --arg key "$output_name" '.[$key].value // empty' >/dev/null; then
    echo "Missing Terraform output '$output_name' in state."
    echo "Run 'terraform -chdir=infrastructure apply' first so outputs are recorded."
    exit 1
  fi
done

admin_api_base_url="$(echo "$tf_outputs_json" | jq -r '.frontend_admin_api_base_url.value')"
public_api_base_url="$(echo "$tf_outputs_json" | jq -r '.frontend_public_api_base_url.value')"
user_pool_id="$(echo "$tf_outputs_json" | jq -r '.frontend_cognito_user_pool_id.value')"
client_id="$(echo "$tf_outputs_json" | jq -r '.frontend_cognito_client_id.value')"
aws_region="$(echo "$tf_outputs_json" | jq -r '.frontend_aws_region.value')"

cat > "$ENV_FILE" <<ENV
VITE_ADMIN_API_BASE_URL=$admin_api_base_url
VITE_PUBLIC_API_BASE_URL=$public_api_base_url
VITE_API_BASE_URL=$admin_api_base_url
VITE_COGNITO_USER_POOL_ID=$user_pool_id
VITE_COGNITO_CLIENT_ID=$client_id
VITE_AWS_REGION=$aws_region
ENV

echo "Updated $ENV_FILE"

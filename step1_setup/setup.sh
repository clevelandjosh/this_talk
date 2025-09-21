#!/bin/bash

set -euo pipefail

# Constants
ENV_FILE=".env"
TEMPLATE_FILE="setup/prompts.env.template"
VALIDATION_SCRIPT="setup/validate_env.sh"

function error_exit {
    echo "❌ Error: $1"
    exit 1
}

function check_dependencies {
    for cmd in terraform az jq; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "$cmd is not installed. Please install it before proceeding."
        fi
    done
}

function prompt_for_variable {
    local var_name="$1"
    echo -n "Enter value for $var_name: "
    read -r var_value
    if [[ -z "$var_value" ]]; then
        error_exit "Value for $var_name cannot be empty."
    fi
    echo "$var_name=\"$var_value\"" >> "$ENV_FILE"
}

function create_backend_resources {
    echo "🔧 Creating Terraform backend resources..."

    local rg="${RESOURCE_PREFIX}-rg"
    local sa="${RESOURCE_PREFIX}tfstate"
    local container="tfstate"
    local sp_name="${RESOURCE_PREFIX}-terraform-sp"

    echo "📦 Creating storage account..."
    az storage account create \
        --name "$sa" \
        --resource-group "$rg" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --allow-blob-public-access false

    echo "📁 Creating blob container..."
    az storage container create \
        --name "$container" \
        --account-name "$sa"

    echo "🔐 Creating service principal..."
    sp_json=$(az ad sp create-for-rbac \
        --name "$sp_name" \
        --role "Storage Blob Data Contributor" \
        --scopes "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$sa" \
        --sdk-auth)

    echo "$sp_json" > terraform-sp.json

    # Extract SP credentials
    ARM_CLIENT_ID=$(echo "$sp_json" | jq -r .clientId)
    ARM_CLIENT_SECRET=$(echo "$sp_json" | jq -r .clientSecret)
    ARM_TENANT_ID=$(echo "$sp_json" | jq -r .tenantId)

    echo "✅ Backend resources created."

    # Append backend config to .env
    {
        echo "TF_STATE_STORAGE_ACCOUNT_NAME=\"$sa\""
        echo "TF_STATE_CONTAINER_NAME=\"$container\""
        echo "TF_STATE_KEY=\"terraform.tfstate\""
        echo "ARM_CLIENT_ID=\"$ARM_CLIENT_ID\""
        echo "ARM_CLIENT_SECRET=\"$ARM_CLIENT_SECRET\""
        echo "ARM_TENANT_ID=\"$ARM_TENANT_ID\""
    } >> "$ENV_FILE"
}

# Start
echo "🔐 Azure Security Demo Setup Script"
echo "-----------------------------------"

check_dependencies

# Handle existing .env
if [ -f "$ENV_FILE" ]; then
    echo "⚠️  Existing .env file found. Overwrite? (y/n)"
    read -r overwrite
    if [[ "$overwrite" != "y" ]]; then
        echo "✅ Using existing .env file."
        source "$ENV_FILE"
        exit 0
    fi
    rm -f "$ENV_FILE"
fi

# Create new .env file
echo "🔧 Creating new .env file..."
touch "$ENV_FILE"

# Prompt for variables
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
        continue
    fi
    var_name=$(echo "$line" | cut -d= -f1)
    prompt_for_variable "$var_name"
done < "$TEMPLATE_FILE"

# Export variables
set -a
source "$ENV_FILE"
set +a

# Create backend resources
create_backend_resources

# Validate environment
echo "🔍 Validating environment variables..."
bash "$VALIDATION_SCRIPT" || error_exit "Environment validation failed."

echo "✅ Environment setup complete. You can now run Terraform."

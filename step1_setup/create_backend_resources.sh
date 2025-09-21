#!/bin/bash

set -euo pipefail

# Load environment
source .env

# Constants
RESOURCE_GROUP="${RESOURCE_PREFIX}-rg"
STORAGE_ACCOUNT_NAME="${RESOURCE_PREFIX}tfstate"
CONTAINER_NAME="tfstate"
SP_NAME="${RESOURCE_PREFIX}-terraform-sp"

echo "🔧 Creating storage account for Terraform state..."

# Create storage account
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false

# Create blob container
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME"

echo "🔐 Creating service principal for Terraform..."

# Create service principal
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "Storage Blob Data Contributor" \
  --scopes "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME" \
  --sdk-auth)

echo "$SP_OUTPUT" > terraform-sp.json

echo "✅ Service principal created and assigned permissions."

echo "📦 Backend configuration:"
echo "storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "container_name       = \"$CONTAINER_NAME\""
echo "key                  = \"terraform.tfstate\""

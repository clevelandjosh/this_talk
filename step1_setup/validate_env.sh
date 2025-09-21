#!/bin/bash

REQUIRED_VARS=(
  "ARM_CLIENT_ID"
  "ARM_CLIENT_SECRET"
  "ARM_SUBSCRIPTION_ID"
  "ARM_TENANT_ID"
  "VNET_ADDRESS_SPACE"
  "JIRA_ADMIN_EMAIL"
  "CROWDSTRIKE_API_KEY"
  "MCP_SERVER_COUNT"
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing required variable: $var"
    exit 1
  fi
done

echo "✅ All required variables are set."
exit 0

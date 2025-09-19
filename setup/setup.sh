#!/bin/bash

set -euo pipefail

# Constants
ENV_FILE=".env"
TEMPLATE_FILE="setup/prompts.env.template"
VALIDATION_SCRIPT="setup/validate_env.sh"

# Functions
function error_exit {
    echo "❌ Error: $1"
    exit 1
}

function check_dependencies {
    for cmd in terraform az; do
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

# Start
echo "🔐 Azure Security Demo Setup Script"
echo "-----------------------------------"

# Check dependencies
echo "🔍 Checking required tools..."
check_dependencies
echo "✅ All required tools are installed."

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
touch "$ENV_FILE" || error_exit "Failed to create .env file."

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

# Validate environment
echo "🔍 Validating environment variables..."
if [ ! -f "$VALIDATION_SCRIPT" ]; then
    error_exit "Validation script not found at $VALIDATION_SCRIPT"
fi

bash "$VALIDATION_SCRIPT" || error_exit "Environment validation failed."

echo "✅ Environment setup complete. You can now run Terraform."

#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$SCRIPT_DIR/github-secrets.env"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Dependency checks
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    for cmd in az gh jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo
        echo "Please install the missing dependencies:"
        echo "  Azure CLI:   brew install azure-cli"
        echo "  GitHub CLI:  brew install gh"
        echo "  jq:          brew install jq"
        exit 1
    fi
    
    log_success "All dependencies are installed"
}

# Prompt for user input with validation
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    local validation_pattern="${4:-.*}"
    local example="${5:-}"
    
    while true; do
        echo
        echo -e "${BLUE}$prompt${NC}"
        if [ -n "$example" ]; then
            echo -e "${YELLOW}Example: $example${NC}"
        fi
        
        if [ "$is_secret" = "true" ]; then
            echo -n "Enter value (hidden): "
            read -rs input
            echo
        else
            echo -n "Enter value: "
            read -r input
        fi
        
        if [[ -z "$input" ]]; then
            log_warning "Value cannot be empty. Please try again."
            continue
        fi
        
        if [[ ! "$input" =~ $validation_pattern ]]; then
            log_warning "Invalid format. Please try again."
            continue
        fi
        
        # Export to environment for immediate use
        export "$var_name"="$input"
        
        # Store in secrets file for later reference
        echo "$var_name=\"$input\"" >> "$SECRETS_FILE"
        
        break
    done
}

# Confirm action
confirm() {
    local prompt="$1"
    echo
    echo -e "${YELLOW}$prompt (y/N)${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check Azure authentication
check_azure_auth() {
    log_info "Checking Azure CLI authentication..."
    
    if ! az account show &> /dev/null; then
        log_warning "Not logged into Azure CLI"
        if confirm "Would you like to login to Azure now?"; then
            az login || error_exit "Azure login failed"
            log_success "Azure login successful"
        else
            error_exit "Azure authentication required to continue"
        fi
    else
        local account_info=$(az account show)
        local subscription_name=$(echo "$account_info" | jq -r '.name')
        local subscription_id=$(echo "$account_info" | jq -r '.id')
        log_success "Already logged into Azure"
        log_info "Current subscription: $subscription_name ($subscription_id)"
        
        if ! confirm "Use this subscription for the setup?"; then
            log_info "Please run 'az account set --subscription <subscription-id>' to change subscription"
            exit 1
        fi
        
        export AZURE_SUBSCRIPTION_ID="$subscription_id"
        echo "AZURE_SUBSCRIPTION_ID=\"$subscription_id\"" >> "$SECRETS_FILE"
    fi
}

# Check GitHub authentication
check_github_auth() {
    log_info "Checking GitHub CLI authentication..."
    
    if ! gh auth status &> /dev/null; then
        log_warning "Not logged into GitHub CLI"
        if confirm "Would you like to login to GitHub now?"; then
            gh auth login || error_exit "GitHub login failed"
            log_success "GitHub login successful"
        else
            error_exit "GitHub authentication required to continue"
        fi
    else
        local github_user=$(gh api user --jq '.login')
        log_success "Already logged into GitHub as: $github_user"
    fi
}

# Create Azure Service Principal
create_service_principal() {
    log_info "Creating Azure Service Principal for GitHub Actions..."
    
    local sp_name="github-actions-terraform-$(date +%s)"
    local subscription_id="${AZURE_SUBSCRIPTION_ID}"
    
    echo
    echo "Service Principal Details:"
    echo "  Name: $sp_name"
    echo "  Subscription: $subscription_id"
    echo "  Role: Contributor"
    
    if ! confirm "Create this service principal?"; then
        log_warning "Skipping service principal creation"
        return 0
    fi
    
    log_info "Creating service principal..."
    local sp_output
    sp_output=$(az ad sp create-for-rbac \
        --name "$sp_name" \
        --role "Contributor" \
        --scopes "/subscriptions/$subscription_id" \
        --sdk-auth 2>/dev/null) || error_exit "Failed to create service principal"
    
    # Extract credentials
    local client_id=$(echo "$sp_output" | jq -r '.clientId')
    local client_secret=$(echo "$sp_output" | jq -r '.clientSecret')
    local tenant_id=$(echo "$sp_output" | jq -r '.tenantId')
    
    # Store credentials
    export AZURE_CLIENT_ID="$client_id"
    export AZURE_CLIENT_SECRET="$client_secret"
    export AZURE_TENANT_ID="$tenant_id"
    
    # Save to secrets file
    {
        echo "AZURE_CLIENT_ID=\"$client_id\""
        echo "AZURE_CLIENT_SECRET=\"$client_secret\""
        echo "AZURE_TENANT_ID=\"$tenant_id\""
    } >> "$SECRETS_FILE"
    
    log_success "Service principal created successfully"
    log_info "Client ID: $client_id"
    
    # Save full SP output for reference
    echo "$sp_output" > "$SCRIPT_DIR/service-principal.json"
    log_info "Full service principal details saved to: $SCRIPT_DIR/service-principal.json"
}

# Configure storage account permissions
configure_storage_permissions() {
    if [ -z "${TF_STATE_STORAGE_ACCOUNT_NAME:-}" ]; then
        log_warning "Storage account name not provided, skipping storage permissions"
        return 0
    fi
    
    log_info "Configuring storage account permissions..."
    
    local storage_account="${TF_STATE_STORAGE_ACCOUNT_NAME}"
    local resource_group="${TF_STATE_RESOURCE_GROUP:-}"
    local client_id="${AZURE_CLIENT_ID}"
    
    if [ -z "$resource_group" ]; then
        # Try to find the resource group
        resource_group=$(az storage account list --query "[?name=='$storage_account'].resourceGroup | [0]" -o tsv)
        if [ -z "$resource_group" ] || [ "$resource_group" = "null" ]; then
            log_warning "Could not find resource group for storage account: $storage_account"
            log_info "Please manually assign 'Storage Blob Data Contributor' role to the service principal"
            return 0
        fi
    fi
    
    log_info "Assigning Storage Blob Data Contributor role to service principal..."
    az role assignment create \
        --assignee "$client_id" \
        --role "Storage Blob Data Contributor" \
        --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/$resource_group/providers/Microsoft.Storage/storageAccounts/$storage_account" \
        || log_warning "Failed to assign storage role. You may need to do this manually."
    
    log_success "Storage permissions configured"
}

# Set GitHub secrets
set_github_secrets() {
    log_info "Setting GitHub repository secrets..."
    
    local repo_owner=$(gh repo view --json owner --jq '.owner.login')
    local repo_name=$(gh repo view --json name --jq '.name')
    
    log_info "Repository: $repo_owner/$repo_name"
    
    if ! confirm "Set secrets for this repository?"; then
        log_warning "Skipping GitHub secrets setup"
        log_info "You can manually set secrets using the GitHub web interface"
        return 0
    fi
    
    # Define secrets to set
    local secrets=(
        "AZURE_CLIENT_ID"
        "AZURE_CLIENT_SECRET"
        "AZURE_TENANT_ID"
        "AZURE_SUBSCRIPTION_ID"
        "TF_STATE_STORAGE_ACCOUNT_NAME"
        "TF_STATE_CONTAINER_NAME"
        "TF_STATE_KEY"
        "VNET_ADDRESS_SPACE"
        "ADMIN_EMAIL"
        "ADMIN_PASSWORD"
        "JIRA_ADMIN_EMAIL"
        "CROWDSTRIKE_API_KEY"
    )
    
    local optional_secrets=(
        "MCP_SERVER_COUNT"
        "LOCATION"
        "RESOURCE_PREFIX"
    )
    
    # Set required secrets
    for secret in "${secrets[@]}"; do
        if [ -n "${!secret:-}" ]; then
            log_info "Setting secret: $secret"
            echo "${!secret}" | gh secret set "$secret" || log_warning "Failed to set secret: $secret"
        else
            log_warning "Secret $secret is not set in environment"
        fi
    done
    
    # Set optional secrets
    for secret in "${optional_secrets[@]}"; do
        if [ -n "${!secret:-}" ]; then
            log_info "Setting optional secret: $secret"
            echo "${!secret}" | gh secret set "$secret" || log_warning "Failed to set secret: $secret"
        fi
    done
    
    log_success "GitHub secrets configured"
}

# Create GitHub environments
create_github_environments() {
    log_info "Creating GitHub environments with protection rules..."
    
    # Note: Environment creation via CLI requires GitHub Enterprise or organization repos
    # For personal repos, this needs to be done via web interface
    
    log_info "Creating production environment..."
    gh api repos/:owner/:repo/environments/production \
        --method PUT \
        --field "wait_timer=300" \
        --field "prevent_self_review=true" \
        2>/dev/null || log_warning "Could not create production environment via CLI. Please create manually in GitHub web interface."
    
    log_info "Creating destruction environment..."
    gh api repos/:owner/:repo/environments/destruction \
        --method PUT \
        --field "wait_timer=600" \
        --field "prevent_self_review=true" \
        2>/dev/null || log_warning "Could not create destruction environment via CLI. Please create manually in GitHub web interface."
    
    log_info "Environment setup instructions:"
    echo "  1. Go to: https://github.com/$(gh repo view --json owner,name --jq '.owner.login + \"/\" + .name')/settings/environments"
    echo "  2. Configure 'production' environment with:"
    echo "     - Required reviewers"
    echo "     - Wait timer: 5 minutes"
    echo "     - Deployment branches: main only"
    echo "  3. Configure 'destruction' environment with:"
    echo "     - Required reviewers (multiple)"
    echo "     - Wait timer: 10 minutes"
    echo "     - Manual approval only"
}

# Main setup flow
main() {
    echo
    echo "🚀 GitHub Actions Terraform CI/CD Setup"
    echo "========================================"
    echo
    echo "This script will help you configure GitHub Actions for automated Terraform deployments."
    echo
    
    # Initialize secrets file
    rm -f "$SECRETS_FILE"
    touch "$SECRETS_FILE"
    
    # Step 1: Check dependencies
    check_dependencies
    
    # Step 2: Check authentication
    check_azure_auth
    check_github_auth
    
    echo
    log_info "Starting interactive configuration..."
    
    # Step 3: Collect Terraform backend configuration
    echo
    echo "📦 Terraform Backend Configuration"
    echo "=================================="
    prompt_input "Enter the Terraform state storage account name:" "TF_STATE_STORAGE_ACCOUNT_NAME" false "^[a-z0-9]{3,24}$" "secconftfstate"
    prompt_input "Enter the Terraform state container name:" "TF_STATE_CONTAINER_NAME" false "^[a-z0-9-]{3,63}$" "tfstate"
    prompt_input "Enter the Terraform state key (filename):" "TF_STATE_KEY" false ".*\.tfstate$" "terraform.tfstate"
    prompt_input "Enter the resource group name (optional):" "TF_STATE_RESOURCE_GROUP" false "^[a-zA-Z0-9_.-]*$" "secconf-rg"
    
    # Step 3.5: Network Configuration
    echo
    echo "🌐 Network Configuration"
    echo "======================="
    prompt_input "Enter the VNet address space (CIDR notation):" "VNET_ADDRESS_SPACE" false "^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$" "10.0.0.0/16"
    
    # Step 4: Collect application configuration
    echo
    echo "🔧 Application Configuration"
    echo "============================"
    prompt_input "Enter administrator email address:" "ADMIN_EMAIL" false "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" "admin@example.com"
    prompt_input "Enter administrator password:" "ADMIN_PASSWORD" true "^.{8,}$"
    prompt_input "Enter Jira admin email address:" "JIRA_ADMIN_EMAIL" false "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" "jira-admin@example.com"
    prompt_input "Enter CrowdStrike API key:" "CROWDSTRIKE_API_KEY" true "^[a-zA-Z0-9_-]+$"
    
    # Optional configuration
    echo
    echo "⚙️  Optional Configuration"
    echo "========================="
    if confirm "Would you like to configure optional settings?"; then
        prompt_input "Enter number of MCP servers:" "MCP_SERVER_COUNT" false "^[0-9]+$" "2"
        prompt_input "Enter Azure region:" "LOCATION" false "^[a-z0-9]+$" "eastus"
        prompt_input "Enter resource prefix:" "RESOURCE_PREFIX" false "^[a-zA-Z0-9-]{3,10}$" "secconf"
    else
        # Set defaults
        export MCP_SERVER_COUNT="2"
        export LOCATION="eastus"
        export RESOURCE_PREFIX="secconf"
        {
            echo "MCP_SERVER_COUNT=\"2\""
            echo "LOCATION=\"eastus\""
            echo "RESOURCE_PREFIX=\"secconf\""
        } >> "$SECRETS_FILE"
    fi
    
    # Step 5: Create service principal
    echo
    echo "🔐 Azure Service Principal"
    echo "========================="
    create_service_principal
    
    # Step 6: Configure storage permissions
    echo
    echo "📁 Storage Permissions"
    echo "====================="
    configure_storage_permissions
    
    # Step 7: Set GitHub secrets
    echo
    echo "🔑 GitHub Secrets"
    echo "================"
    set_github_secrets
    
    # Step 8: Create environments
    echo
    echo "🛡️  GitHub Environments"
    echo "======================"
    create_github_environments
    
    # Final summary
    echo
    echo "🎉 Setup Complete!"
    echo "================="
    log_success "GitHub Actions CI/CD setup completed successfully"
    echo
    echo "📋 Summary:"
    echo "  ✅ Dependencies verified"
    echo "  ✅ Azure and GitHub authentication confirmed"
    echo "  ✅ Service principal created"
    echo "  ✅ Storage permissions configured"
    echo "  ✅ GitHub secrets set"
    echo "  ✅ Environment setup instructions provided"
    echo
    echo "📁 Files created:"
    echo "  - $SECRETS_FILE (contains all configuration)"
    echo "  - $SCRIPT_DIR/service-principal.json (service principal details)"
    echo
    echo "🔒 Security notes:"
    echo "  - Keep the secrets file secure and do not commit to version control"
    echo "  - Service principal credentials are stored in service-principal.json"
    echo "  - Complete environment setup in GitHub web interface"
    echo
    echo "🚀 Next steps:"
    echo "  1. Complete GitHub environment configuration (see instructions above)"
    echo "  2. Test the workflow by making a change to Terraform files"
    echo "  3. Create a pull request to verify the plan workflow"
    echo "  4. Merge to main to test the apply workflow"
    echo
    log_info "GitHub Actions CI/CD is ready to use!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
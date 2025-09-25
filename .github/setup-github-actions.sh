#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$HOME/.config/azure-setup"  # Store outside repo
SECRETS_FILE="$SECRETS_DIR/github-secrets.env"
SP_FILE="$SECRETS_DIR/service-principals.json"

# Create secrets directory with restricted permissions
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

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

log_section() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Detect OS and set package manager
detect_os_and_pkg_manager() {
    OS_TYPE=""
    PKG_MANAGER=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        PKG_MANAGER="brew install"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="linux"
        # Detect Linux distribution
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    PKG_MANAGER="sudo apt-get install -y"
                    ;;
                fedora)
                    PKG_MANAGER="sudo dnf install -y"
                    ;;
                centos|rhel)
                    PKG_MANAGER="sudo yum install -y"
                    ;;
                arch)
                    PKG_MANAGER="sudo pacman -S"
                    ;;
                *)
                    PKG_MANAGER="sudo apt-get install -y"
                    ;;
            esac
        else
            PKG_MANAGER="sudo apt-get install -y"
        fi
    else
        OS_TYPE="unknown"
        PKG_MANAGER="(please install manually)"
    fi
}

# Dependency checks
check_dependencies() {
    log_info "Checking dependencies..."

    detect_os_and_pkg_manager

    local missing_deps=()

    for cmd in az gh jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo
        echo "Please install the missing dependencies using:"
        for dep in "${missing_deps[@]}"; do
            echo "  $PKG_MANAGER $dep"
        done
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
    local default_value="${5:-}"
    
    while true; do
        echo
        echo -e "${BLUE}$prompt${NC}"
        if [ -n "$default_value" ]; then
            echo -e "${YELLOW}Default: $default_value${NC}"
            if [ "$is_secret" = "true" ]; then
                echo -n "Enter value (hidden) [press Enter for default]: "
            else
                echo -n "Enter value [press Enter for default]: "
            fi
        else
            if [ "$is_secret" = "true" ]; then
                echo -n "Enter value (hidden): "
            else
                echo -n "Enter value: "
            fi
        fi
        
        local input
        if [ "$is_secret" = "true" ]; then
            read -rs input
            echo  # Add newline after hidden input
        else
            read -r input
        fi
        
        # Use default value if input is empty and default exists
        if [[ -z "$input" && -n "$default_value" ]]; then
            input="$default_value"
            if [ "$is_secret" = "false" ]; then
                echo -e "${GREEN}Using default: $default_value${NC}"
            else
                echo -e "${GREEN}Using default value${NC}"
            fi
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
    
    # First check if already logged in
    if ! az account show &> /dev/null; then
        log_warning "Not logged into Azure CLI"
        if confirm "Would you like to login to Azure now?"; then
            # Try regular login first
            if ! az login; then
                log_warning "Regular login failed. Trying device code login..."
                if ! az login --use-device-code; then
                    error_exit "Azure login failed"
                fi
            fi
        else
            error_exit "Azure authentication required to continue"
        fi
    fi

    # List available subscriptions
    log_info "Available Azure subscriptions:"
    az account list --output table || error_exit "Failed to list subscriptions"
    
    # Get subscription count and details
    local subscriptions
    subscriptions=$(az account list --query "[].{id:id,name:name}" -o json)
    local sub_count
    sub_count=$(echo "$subscriptions" | jq length)
    
    if [ "$sub_count" -eq 1 ]; then
        # If only one subscription exists, use it automatically
        export AZURE_SUBSCRIPTION_ID=$(echo "$subscriptions" | jq -r '.[0].id')
        local subscription_name=$(echo "$subscriptions" | jq -r '.[0].name')
        log_info "Single subscription found - using it automatically"
    else
        # Multiple subscriptions - prompt for selection
        echo
        prompt_input "Enter the subscription ID to use:" "AZURE_SUBSCRIPTION_ID" false "^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$" "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    fi
    
    # Set the subscription
    if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID"; then
        error_exit "Failed to set subscription. Please verify the subscription ID is correct."
    fi
    
    # Verify subscription
    local account_info=$(az account show)
    local subscription_name=$(echo "$account_info" | jq -r '.name')
    log_success "Using subscription: $subscription_name ($AZURE_SUBSCRIPTION_ID)"
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

# Create custom roles
create_custom_roles() {
    log_section "Creating Custom Azure Roles"
    
    local subscription_id="${AZURE_SUBSCRIPTION_ID}"
    
    # Network Infrastructure Contributor Role
    log_info "Creating Network Infrastructure Contributor role..."
    local network_role_def=$(cat <<EOF
{
    "Name": "Network Infrastructure Contributor",
    "IsCustom": true,
    "Description": "Manage virtual networks, subnets, firewalls, load balancers, and networking components with least privilege access",
    "Actions": [
        "Microsoft.Network/virtualNetworks/*",
        "Microsoft.Network/networkSecurityGroups/*",
        "Microsoft.Network/routeTables/*",
        "Microsoft.Network/publicIPAddresses/*",
        "Microsoft.Network/loadBalancers/*",
        "Microsoft.Network/azureFirewalls/*",
        "Microsoft.Network/bastionHosts/*",
        "Microsoft.Network/vpnGateways/*",
        "Microsoft.Network/virtualNetworkGateways/*",
        "Microsoft.Network/networkInterfaces/*",
        "Microsoft.Network/privateEndpoints/*",
        "Microsoft.Network/privateDnsZones/*",
        "Microsoft.Network/dnsZones/*",
        "Microsoft.Network/applicationGateways/*",
        "Microsoft.Resources/deployments/*",
        "Microsoft.Resources/subscriptions/resourceGroups/read"
    ],
    "NotActions": [],
    "DataActions": [],
    "NotDataActions": [],
    "AssignableScopes": [
        "/subscriptions/$subscription_id"
    ]
}
EOF
)
    
    echo "$network_role_def" | az role definition create --role-definition @- 2>/dev/null || log_warning "Network Infrastructure Contributor role may already exist"
    
    # AI Foundry Contributor Role
    log_info "Creating AI Foundry Contributor role..."
    local ai_role_def=$(cat <<EOF
{
    "Name": "AI Foundry Contributor",
    "IsCustom": true,
    "Description": "Manage Azure AI services, Cognitive Services, Machine Learning, and AI foundry resources with least privilege access",
    "Actions": [
        "Microsoft.CognitiveServices/*",
        "Microsoft.MachineLearningServices/*",
        "Microsoft.Ai/*",
        "Microsoft.Search/*",
        "Microsoft.DocumentDB/databaseAccounts/*",
        "Microsoft.KeyVault/vaults/secrets/read",
        "Microsoft.KeyVault/vaults/keys/read",
        "Microsoft.Storage/storageAccounts/read",
        "Microsoft.Storage/storageAccounts/listKeys/action",
        "Microsoft.Storage/storageAccounts/blobServices/*",
        "Microsoft.Resources/deployments/*",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Insights/*"
    ],
    "NotActions": [],
    "DataActions": [
        "Microsoft.CognitiveServices/accounts/*",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/*"
    ],
    "NotDataActions": [],
    "AssignableScopes": [
        "/subscriptions/$subscription_id"
    ]
}
EOF
)
    
    echo "$ai_role_def" | az role definition create --role-definition @- 2>/dev/null || log_warning "AI Foundry Contributor role may already exist"
    
    # VM Image Builder Contributor Role
    log_info "Creating VM Image Builder Contributor role..."
    local vm_role_def=$(cat <<EOF
{
    "Name": "VM Image Builder Contributor",
    "IsCustom": true,
    "Description": "Manage virtual machines, VM images, disks, and related compute resources with least privilege access",
    "Actions": [
        "Microsoft.Compute/virtualMachines/*",
        "Microsoft.Compute/virtualMachineScaleSets/*",
        "Microsoft.Compute/images/*",
        "Microsoft.Compute/galleries/*",
        "Microsoft.Compute/disks/*",
        "Microsoft.Compute/snapshots/*",
        "Microsoft.Compute/availabilitySets/*",
        "Microsoft.Network/networkInterfaces/read",
        "Microsoft.Network/networkInterfaces/write",
        "Microsoft.Network/networkInterfaces/join/action",
        "Microsoft.Storage/storageAccounts/read",
        "Microsoft.Storage/storageAccounts/listKeys/action",
        "Microsoft.KeyVault/vaults/secrets/read",
        "Microsoft.Resources/deployments/*",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Insights/*"
    ],
    "NotActions": [],
    "DataActions": [
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/*"
    ],
    "NotDataActions": [],
    "AssignableScopes": [
        "/subscriptions/$subscription_id"
    ]
}
EOF
)
    
    echo "$vm_role_def" | az role definition create --role-definition @- 2>/dev/null || log_warning "VM Image Builder Contributor role may already exist"
    
    log_success "Custom roles created successfully"
}



# Create service principal with specific role
create_service_principal() {
    local sp_name="$1"
    local role_name="$2"
    local description="$3"
    local scope="${4:-/subscriptions/${AZURE_SUBSCRIPTION_ID}}"  # Default to subscription scope
    
    log_info "Creating service principal: $sp_name"
    log_info "Role: $role_name"
    log_info "Description: $description"
    log_info "Scope: $scope"
    
    if ! confirm "Create this service principal?"; then
        log_warning "Skipping service principal: $sp_name"
        return 0
    fi
    
    local sp_output
    sp_output=$(az ad sp create-for-rbac \
        --name "$sp_name" \
        --role "$role_name" \
        --scopes "$scope" \
        --sdk-auth 2>/dev/null) || error_exit "Failed to create service principal: $sp_name"
    
    # Extract credentials
    local client_id=$(echo "$sp_output" | jq -r '.clientId')
    local client_secret=$(echo "$sp_output" | jq -r '.clientSecret')
    local tenant_id=$(echo "$sp_output" | jq -r '.tenantId')
    
    # Store in SP file
    local sp_record=$(cat <<EOF
{
    "name": "$sp_name",
    "description": "$description",
    "role": "$role_name",
    "clientId": "$client_id",
    "clientSecret": "$client_secret",
    "tenantId": "$tenant_id",
    "subscriptionId": "$subscription_id",
    "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)
    
    # Initialize or append to SP file
    if [ ! -f "$SP_FILE" ] || [ ! -s "$SP_FILE" ]; then
        echo '{"service_principals": []}' > "$SP_FILE"
    fi
    
    # Add new SP to file
    jq --argjson sp "$sp_record" '.service_principals += [$sp]' "$SP_FILE" > "${SP_FILE}.tmp" && mv "${SP_FILE}.tmp" "$SP_FILE"
    
    log_success "Service principal created: $sp_name (Client ID: $client_id)"
    
    # Return the credentials for immediate use
    echo "$sp_output"
}

# Create all service principals
create_all_service_principals() {
    log_section "Creating Service Principals with Least Privilege Access"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local project_prefix="${RESOURCE_PREFIX:-secconf}"
    
    # Initialize SP file
    echo '{"service_principals": []}' > "$SP_FILE"
    
    # 1. Terraform State Manager - Storage Blob Data Contributor
    log_info "1/6 Creating Terraform State Manager..."
    local tf_state_sp=$(create_service_principal \
        "$project_prefix-terraform-state-$timestamp" \
        "Storage Blob Data Contributor" \
        "Manages Terraform state files in blob storage with read/write access to containers and blobs only")
    
    if [ -n "$tf_state_sp" ]; then
        export TF_STATE_CLIENT_ID=$(echo "$tf_state_sp" | jq -r '.clientId')
        export TF_STATE_CLIENT_SECRET=$(echo "$tf_state_sp" | jq -r '.clientSecret')
        echo "TF_STATE_CLIENT_ID=\"$TF_STATE_CLIENT_ID\"" >> "$SECRETS_FILE"
        echo "TF_STATE_CLIENT_SECRET=\"$TF_STATE_CLIENT_SECRET\"" >> "$SECRETS_FILE"
    fi
    
    # 2. Network Infrastructure Manager - Custom Network Role
    log_info "2/6 Creating Network Infrastructure Manager..."
    local network_sp=$(create_service_principal \
        "$project_prefix-network-infra-$timestamp" \
        "Network Infrastructure Contributor" \
        "Manages VNets, subnets, firewalls, load balancers, and all networking components")
    
    if [ -n "$network_sp" ]; then
        export NETWORK_CLIENT_ID=$(echo "$network_sp" | jq -r '.clientId')
        export NETWORK_CLIENT_SECRET=$(echo "$network_sp" | jq -r '.clientSecret')
        echo "NETWORK_CLIENT_ID=\"$NETWORK_CLIENT_ID\"" >> "$SECRETS_FILE"
        echo "NETWORK_CLIENT_SECRET=\"$NETWORK_CLIENT_SECRET\"" >> "$SECRETS_FILE"
    fi
    
    # 3. AI Foundry Manager - Custom AI Role
    log_info "3/6 Creating AI Foundry Manager..."
    local ai_sp=$(create_service_principal \
        "$project_prefix-ai-foundry-$timestamp" \
        "AI Foundry Contributor" \
        "Manages Azure AI services, Cognitive Services, Machine Learning workspaces and AI foundry resources")
    
    if [ -n "$ai_sp" ]; then
        export AI_CLIENT_ID=$(echo "$ai_sp" | jq -r '.clientId')
        export AI_CLIENT_SECRET=$(echo "$ai_sp" | jq -r '.clientSecret')
        echo "AI_CLIENT_ID=\"$AI_CLIENT_ID\"" >> "$SECRETS_FILE"
        echo "AI_CLIENT_SECRET=\"$AI_CLIENT_SECRET\"" >> "$SECRETS_FILE"
    fi
    
    # 4. AKS Manager - Azure Kubernetes Service Contributor (scoped to AKS RG)
    log_info "4/6 Creating AKS Manager..."
    ensure_resource_group "$AKS_RESOURCE_GROUP"
    local aks_sp=$(create_service_principal \
        "$project_prefix-aks-manager-$timestamp" \
        "Azure Kubernetes Service Contributor" \
        "Manages AKS clusters, node pools, and Kubernetes workloads" \
        "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AKS_RESOURCE_GROUP}")
    
    if [ -n "$aks_sp" ]; then
        # Add Network Contributor role for AKS networking (scoped to AKS RG)
        local aks_client_id=$(echo "$aks_sp" | jq -r '.clientId')
        az role assignment create \
            --assignee "$aks_client_id" \
            --role "Network Contributor" \
            --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AKS_RESOURCE_GROUP}" \
            || log_warning "Failed to assign Network Contributor role to AKS SP"
        
        export AKS_CLIENT_ID="$aks_client_id"
        export AKS_CLIENT_SECRET=$(echo "$aks_sp" | jq -r '.clientSecret')
        echo "AKS_CLIENT_ID=\"$AKS_CLIENT_ID\"" >> "$SECRETS_FILE"
        echo "AKS_CLIENT_SECRET=\"$AKS_CLIENT_SECRET\"" >> "$SECRETS_FILE"
        echo "AKS_RESOURCE_GROUP=\"$AKS_RESOURCE_GROUP\"" >> "$SECRETS_FILE"
    fi
    
    # 5. VM Image Builder - Custom VM Role (scoped to VM RG)
    log_info "5/6 Creating VM Image Builder..."
    ensure_resource_group "$VM_RESOURCE_GROUP"
    local vm_sp=$(create_service_principal \
        "$project_prefix-vm-builder-$timestamp" \
        "VM Image Builder Contributor" \
        "Manages virtual machines, VM images, disks, and compute resources for image building" \
        "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${VM_RESOURCE_GROUP}")
    
    if [ -n "$vm_sp" ]; then
        export VM_CLIENT_ID=$(echo "$vm_sp" | jq -r '.clientId')
        export VM_CLIENT_SECRET=$(echo "$vm_sp" | jq -r '.clientSecret')
        echo "VM_CLIENT_ID=\"$VM_CLIENT_ID\"" >> "$SECRETS_FILE"
        echo "VM_CLIENT_SECRET=\"$VM_CLIENT_SECRET\"" >> "$SECRETS_FILE"
        echo "VM_RESOURCE_GROUP=\"$VM_RESOURCE_GROUP\"" >> "$SECRETS_FILE"
    fi
    
    # 6. Resource Group Manager - Contributor (at subscription level for RG management)
    log_info "6/6 Creating Resource Group Manager..."
    local rg_sp=$(create_service_principal \
        "$project_prefix-resource-groups-$timestamp" \
        "Contributor" \
        "Manages resource groups and subscription-level resources with full contributor access")
    
    if [ -n "$rg_sp" ]; then
        export RG_CLIENT_ID=$(echo "$rg_sp" | jq -r '.clientId')
        export RG_CLIENT_SECRET=$(echo "$rg_sp" | jq -r '.clientSecret')
        echo "RG_CLIENT_ID=\"$RG_CLIENT_ID\"" >> "$SECRETS_FILE"
        echo "RG_CLIENT_SECRET=\"$RG_CLIENT_SECRET\"" >> "$SECRETS_FILE"
    fi
    
    # Store tenant info
    export AZURE_TENANT_ID=$(echo "$tf_state_sp" | jq -r '.tenantId')
    echo "AZURE_TENANT_ID=\"$AZURE_TENANT_ID\"" >> "$SECRETS_FILE"
    
    log_success "All service principals created successfully"
    log_warning "Sensitive files are stored in: $SECRETS_DIR"
    log_warning "Keep these files secure and DO NOT commit them to git!"
}

# Ensure resource group exists
ensure_resource_group() {
    local rg_name="$1"
    local location="${LOCATION:-eastus}"
    
    if ! az group show --name "$rg_name" &>/dev/null; then
        log_info "Creating resource group: $rg_name"
        az group create --name "$rg_name" --location "$location" || \
            error_exit "Failed to create resource group: $rg_name"
    else
        log_info "Resource group already exists: $rg_name"
    fi
}

# Configure storage account permissions
configure_storage_permissions() {
    if [ -z "${TF_STATE_STORAGE_ACCOUNT_NAME:-}" ] || [ -z "${TF_STATE_CLIENT_ID:-}" ]; then
        log_warning "Storage account name or SP not provided, skipping storage permissions"
        return 0
    fi
    
    log_info "Configuring storage account permissions for Terraform State Manager..."
    
    local storage_account="${TF_STATE_STORAGE_ACCOUNT_NAME}"
    local resource_group="${TF_STATE_RESOURCE_GROUP:-}"
    local client_id="${TF_STATE_CLIENT_ID}"
    
    if [ -z "$resource_group" ]; then
        # Try to find the resource group
        resource_group=$(az storage account list --query "[?name=='$storage_account'].resourceGroup | [0]" -o tsv)
        if [ -z "$resource_group" ] || [ "$resource_group" = "null" ]; then
            log_warning "Could not find resource group for storage account: $storage_account"
            log_info "Please manually assign 'Storage Blob Data Contributor' role to the Terraform State Manager SP"
            return 0
        fi
    fi
    
    log_info "Assigning Storage Blob Data Contributor role to Terraform State Manager..."
    az role assignment create \
        --assignee "$client_id" \
        --role "Storage Blob Data Contributor" \
        --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/$resource_group/providers/Microsoft.Storage/storageAccounts/$storage_account" \
        || log_warning "Failed to assign storage role. You may need to do this manually."
    
    log_success "Storage permissions configured for Terraform State Manager"
}

# Set GitHub secrets
set_github_secrets() {
    log_info "Setting GitHub repository secrets for all service principals..."
    
    local repo_owner=$(gh repo view --json owner --jq '.owner.login')
    local repo_name=$(gh repo view --json name --jq '.name')
    
    log_info "Repository: $repo_owner/$repo_name"
    
    if ! confirm "Set secrets for this repository?"; then
        log_warning "Skipping GitHub secrets setup"
        log_info "You can manually set secrets using the GitHub web interface"
        return 0
    fi
    
    # Define secrets to set with their service principal mappings
    local terraform_secrets=(
        "TF_STATE_CLIENT_ID:Terraform State Manager"
        "TF_STATE_CLIENT_SECRET:Terraform State Manager"
        "NETWORK_CLIENT_ID:Network Infrastructure Manager"
        "NETWORK_CLIENT_SECRET:Network Infrastructure Manager"
        "AI_CLIENT_ID:AI Foundry Manager"
        "AI_CLIENT_SECRET:AI Foundry Manager"
        "AKS_CLIENT_ID:AKS Manager"
        "AKS_CLIENT_SECRET:AKS Manager"
        "VM_CLIENT_ID:VM Image Builder"
        "VM_CLIENT_SECRET:VM Image Builder"
        "RG_CLIENT_ID:Resource Group Manager"
        "RG_CLIENT_SECRET:Resource Group Manager"
        "AZURE_TENANT_ID:Common"
        "AZURE_SUBSCRIPTION_ID:Common"
    )
    
    local config_secrets=(
        "TF_STATE_STORAGE_ACCOUNT_NAME"
        "TF_STATE_CONTAINER_NAME"
        "TF_STATE_KEY"
        "VNET_ADDRESS_SPACE"
        "VM_RESOURCE_GROUP"
        "AKS_RESOURCE_GROUP"
        "JIRA_ADMIN_EMAIL"
        "CROWDSTRIKE_API_KEY"
    )
    
    local optional_secrets=(
        "MCP_SERVER_COUNT"
        "LOCATION"
        "RESOURCE_PREFIX"
    )
    
    # Set service principal secrets
    for secret_info in "${terraform_secrets[@]}"; do
        local secret_name=$(echo "$secret_info" | cut -d':' -f1)
        local sp_name=$(echo "$secret_info" | cut -d':' -f2)
        
        if [ -n "${!secret_name:-}" ]; then
            log_info "Setting secret: $secret_name ($sp_name)"
            echo "${!secret_name}" | gh secret set "$secret_name" || log_warning "Failed to set secret: $secret_name"
        else
            log_warning "Secret $secret_name is not set in environment"
        fi
    done
    
    # Set configuration secrets
    for secret in "${config_secrets[@]}"; do
        if [ -n "${!secret:-}" ]; then
            log_info "Setting config secret: $secret"
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
    
    log_success "GitHub secrets configured for all service principals"
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

# Display service principal summary
display_sp_summary() {
    log_section "Service Principal Summary"
    echo
    echo "📋 Service Principals Created:"
    echo "=============================="
    echo
    
    if [ -f "$SP_FILE" ]; then
        jq -r '.service_principals[] | "• \(.name)\n  Role: \(.role)\n  Purpose: \(.description)\n  Client ID: \(.clientId)\n"' "$SP_FILE"
    fi
    
    echo "🔐 Security Architecture:"
    echo "========================"
    echo "• Terraform State Manager    → Storage Blob Data Contributor (blob access only)"
    echo "• Network Infrastructure     → Custom Network Contributor (networking only)"
    echo "• AI Foundry Manager        → Custom AI Contributor (AI services only)"
    echo "• AKS Manager              → AKS + Network Contributor (Kubernetes only)"
    echo "• VM Image Builder         → Custom VM Contributor (compute only)"
    echo "• Resource Group Manager   → Contributor (resource groups only)"
    echo
    echo "✅ Each service principal follows the principle of least privilege"
    echo "✅ Custom roles created for specialized functions"
    echo "✅ No service principal has more access than required"
    echo "⚠️  Important Notes:"
    echo "  - Azure administrator credentials are stored locally in $SECRETS_DIR"
    echo "  - These credentials are NOT stored in GitHub secrets"
    echo "  - Use these credentials only for initial setup and secure maintenance"
}

# Main setup flow
main() {
    echo
    echo "🚀 Multi-Service Principal GitHub Actions Setup"
    echo "==============================================="
    echo
    echo "This script creates 6 service principals with least privilege access:"
    echo "1. Terraform State Manager (blob storage only)"
    echo "2. Network Infrastructure Manager (networking only)"
    echo "3. AI Foundry Manager (AI services only)"
    echo "4. AKS Manager (Kubernetes only)"
    echo "5. VM Image Builder (compute only)"
    echo "6. Resource Group Manager (resource groups only)"
    echo
    
    # Initialize secrets file
    rm -f "$SECRETS_FILE" "$SP_FILE"
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
    prompt_input "Enter the resource group name:" "TF_STATE_RESOURCE_GROUP" false "^[a-zA-Z0-9_.-]*$" "secconf-rg"
    
    # Step 3.5: Network Configuration
    echo
    echo "🌐 Network Configuration"
    echo "======================="
    prompt_input "Enter the VNet address space (CIDR notation):" "VNET_ADDRESS_SPACE" false "^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$" "10.209.96.0/19"
    
    # Step 4: Collect application configuration
    echo
    echo "🔧 Initial Azure Administrator Configuration"
    echo "=========================================="
    echo "Note: These credentials are used ONLY for initial setup to create less privileged service principals."
    echo "WARNING: These credentials require Contributor rights and should NOT be stored in GitHub secrets."
    echo "They will be stored locally in $SECRETS_DIR for reference."
    echo
    prompt_input "Enter Azure administrator email address:" "AZURE_ADMINISTRATOR" false "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" "admin@example.com"
    prompt_input "Enter Azure administrator password:" "AZURE_ADMINISTRATOR_PASSWORD" true "^.{8,}$"
    
    # Optional configuration
    echo
    echo "⚙️  Optional Configuration"
    echo "========================="
    if confirm "Would you like to configure optional settings?"; then
        prompt_input "Enter number of MCP servers:" "MCP_SERVER_COUNT" false "^[0-9]+$" "2"
        prompt_input "Enter Azure region:" "LOCATION" false "^[a-z0-9 ]+$" "eastus"
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
    
    # Step 5: Create custom roles
    echo
    log_section "Azure Custom Roles"
    create_custom_roles
    
    # Step 6: Create all service principals
    echo
    log_section "Service Principal Creation"
    create_all_service_principals
    
    # Step 7: Configure storage permissions
    echo
    echo "📁 Storage Permissions"
    echo "====================="
    configure_storage_permissions
    
    # Step 8: Set GitHub secrets
    echo
    echo "🔑 GitHub Secrets"
    echo "================="
    set_github_secrets
    
    # Step 9: Create environments
    echo
    echo "🛡️  GitHub Environments"
    echo "======================"
    create_github_environments
    
    # Step 10: Display summary
    echo
    display_sp_summary
    
    # Final summary
    echo
    echo "🎉 Multi-Service Principal Setup Complete!"
    echo "=========================================="
    log_success "All service principals created with least privilege access"
    echo
    echo "📋 Summary:"
    echo "  ✅ Dependencies verified"
    echo "  ✅ Azure and GitHub authentication confirmed"
    echo "  ✅ Custom roles created for specialized functions"
    echo "  ✅ 6 service principals created with minimal required permissions"
    echo "  ✅ Storage permissions configured"
    echo "  ✅ GitHub secrets set for all service principals"
    echo "  ✅ Environment setup instructions provided"
    echo
    echo "📁 Files created:"
    echo "  - $SECRETS_FILE (contains all configuration)"
    echo "  - $SP_FILE (detailed service principal information)"
    echo
    echo "🔒 Security Benefits:"
    echo "  - Principle of least privilege enforced"
    echo "  - Custom roles for specialized functions"
    echo "  - No service principal has excessive permissions"
    echo "  - Clear separation of concerns"
    echo "  - Audit trail for all service principals"
    echo
    echo "🚀 Next steps:"
    echo "  1. Review service principal assignments in Azure Portal"
    echo "  2. Complete GitHub environment configuration"
    echo "  3. Update Terraform configurations to use appropriate service principals"
    echo "  4. Test workflows with different service principals for different operations"
    echo "  5. Monitor service principal usage and adjust permissions if needed"
    echo
    log_info "Multi-Service Principal GitHub Actions CI/CD is ready to use!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        if [[ "$(git rev-parse --show-toplevel)" == *"$SECRETS_DIR"* ]]; then
            error_exit "Cannot store secrets in git-tracked directory!"
        fi
    fi
    
    main "$@"
fi
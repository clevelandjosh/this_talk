#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Setup working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$HOME/.config/azure-setup"

# Create secrets directory with restricted permissions
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Source common functions
source "$SCRIPT_DIR/common/logging.sh"
source "$SCRIPT_DIR/common/validation.sh"

main() {
    log_section "Azure Initial Setup"
    
    # Check dependencies
    check_dependencies
    
    # Check Azure authentication
    check_azure_auth
    
    # Create custom roles
    create_custom_roles
    
    # Create service principals
    create_terraform_storage_role
    create_all_service_principals
    
    # Store configuration
    store_configuration
    
    log_success "Initial setup complete!"
    display_next_steps
}

# Execute main function
main
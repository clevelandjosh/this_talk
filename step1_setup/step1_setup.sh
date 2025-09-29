#!/bin/bash

# Source common functions from step 0
source "../step0_account_and_github_setup/common/logging.sh"
source "../step0_account_and_github_setup/common/validation.sh"

main() {
    log_section "Azure Infrastructure Setup"
    
    # Validate environment
    ./validate_env.sh || error_exit "Environment validation failed"
    
    # Create backend resources
    ./create_backend_resources.sh || error_exit "Backend resource creation failed"
    
    # Initialize Terraform
    cd terraform
    terraform init || error_exit "Terraform init failed"
    
    # Apply Terraform configuration
    terraform apply || error_exit "Terraform apply failed"
    
    log_success "Infrastructure setup complete!"
}

# Execute main function
main
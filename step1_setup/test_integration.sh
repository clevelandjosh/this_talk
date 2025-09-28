#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logging.sh"
source "${SCRIPT_DIR}/../common/validation.sh"

# Mock Azure CLI for testing
mock_az() {
    case "$1" in
        "account")
            echo '{"id": "12345678-1234-1234-1234-123456789012", "name": "Test Subscription"}'
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Test Azure authentication
test_azure_auth() {
    # Override az command with mock
    az() { mock_az "$@"; }
    
    # Test authentication check
    check_azure_auth || return 1
    
    return 0
}

# Test resource group creation
test_resource_group_creation() {
    local TEST_RG="test-rg"
    local TEST_LOCATION="eastus"
    
    # Create resource group
    ensure_resource_group "$TEST_RG" "$TEST_LOCATION" || return 1
    
    return 0
}

# Main test runner
main() {
    log_section "Running Integration Tests"
    
    local failed=0
    
    # Run tests
    if test_azure_auth; then
        log_success "Azure Authentication Test Passed"
    else
        log_error "Azure Authentication Test Failed"
        ((failed++))
    fi
    
    if test_resource_group_creation; then
        log_success "Resource Group Creation Test Passed"
    else
        log_error "Resource Group Creation Test Failed"
        ((failed++))
    fi
    
    # Show results
    echo
    log_section "Integration Test Results"
    if [ $failed -eq 0 ]; then
        log_success "All integration tests passed!"
    else
        log_error "$failed integration tests failed"
    fi
    
    return $failed
}

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
#!/bin/bash

# Source the scripts to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logging.sh"
source "${SCRIPT_DIR}/../common/validation.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper function
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_RUN++))
    if eval "$test_function"; then
        log_success "✅ $test_name"
        ((TESTS_PASSED++))
    else
        log_error "❌ $test_name"
        ((TESTS_FAILED++))
    fi
}

# Email validation tests
test_email_validation() {
    # Valid emails
    validate_email "test@example.com" || return 1
    validate_email "user.name+tag@example.co.uk" || return 1
    
    # Invalid emails
    ! validate_email "not-an-email" || return 1
    ! validate_email "@no-username.com" || return 1
    return 0
}

# Subscription ID validation tests
test_subscription_validation() {
    # Valid subscription ID
    validate_subscription_id "12345678-1234-1234-1234-123456789012" || return 1
    
    # Invalid subscription IDs
    ! validate_subscription_id "not-a-subscription-id" || return 1
    ! validate_subscription_id "12345678-1234-1234-1234" || return 1
    return 0
}

# Resource name validation tests
test_resource_name_validation() {
    # Valid resource names
    validate_resource_name "my-resource-123" || return 1
    validate_resource_name "resource_name" || return 1
    
    # Invalid resource names
    ! validate_resource_name "invalid@resource" || return 1
    ! validate_resource_name "no spaces allowed" || return 1
    return 0
}

# CIDR validation tests
test_cidr_validation() {
    # Valid CIDR notations
    validate_cidr "192.168.0.0/24" || return 1
    validate_cidr "10.0.0.0/8" || return 1
    
    # Invalid CIDR notations
    ! validate_cidr "256.256.256.256/24" || return 1
    ! validate_cidr "192.168.1.1" || return 1
    return 0
}

# Run all tests
main() {
    log_section "Running Validation Tests"
    
    run_test "Email Validation" test_email_validation
    run_test "Subscription ID Validation" test_subscription_validation
    run_test "Resource Name Validation" test_resource_name_validation
    run_test "CIDR Validation" test_cidr_validation
    
    echo
    log_section "Test Results"
    echo "Tests Run: $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    
    return $TESTS_FAILED
}

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
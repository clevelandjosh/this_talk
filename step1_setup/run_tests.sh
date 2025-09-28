#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common/logging.sh"


# Run all test suites
main() {
    log_section "Running All Tests"
    
    local failed=0
    
    # Run validation tests
    "${SCRIPT_DIR}/tests/test_validation.sh"
    ((failed+=$?))
    
    # Run integration tests
    "${SCRIPT_DIR}/tests/test_integration.sh"
    ((failed+=$?))
    
    echo
    log_section "Overall Test Results"
    if [ $failed -eq 0 ]; then
        log_success "All test suites passed!"
    else
        log_error "$failed test suites had failures"
    fi
    
    return $failed
}

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# General logging functions
log_section() {
    echo
    echo -e "${PURPLE}🔧 $1${NC}"
    echo "===================="
}

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
    echo -e "${RED}❌ $1${NC}" >&2
}

error_exit() {
    log_error "$1"
    exit 1
}

# Status display functions
display_progress() {
    local message="$1"
    echo -ne "${BLUE}⏳ $message...${NC}\r"
}

display_complete() {
    local message="$1"
    echo -e "${GREEN}✅ $message...Complete${NC}"
}

# Validation result display
display_validation_result() {
    local result=$1
    local message=$2
    
    if [ $result -eq 0 ]; then
        log_success "$message: Passed"
    else
        log_error "$message: Failed"
    fi
    return $result
}

# Display next steps
display_next_steps() {
    echo
    log_section "Next Steps"
    echo -e "1. ${BLUE}Review the created service principals in Azure Portal${NC}"
    echo -e "2. ${BLUE}Verify GitHub secrets were created successfully${NC}"
    echo -e "3. ${BLUE}Proceed to step1_setup to deploy infrastructure${NC}"
    echo
}

# Debug logging (only if DEBUG is set)
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}🔍 DEBUG: $1${NC}" >&2
    fi
}

# Function to ask for confirmation
confirm() {
    local message="${1:-Are you sure?}"
    local response
    
    while true; do
        echo -en "${YELLOW}$message [y/N]: ${NC}"
        read -r response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                return 0
                ;;
            [nN][oO]|[nN]|"")
                return 1
                ;;
            *)
                echo "Please answer yes/y or no/n"
                ;;
        esac
    done
}
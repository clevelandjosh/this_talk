#!/bin/bash

# Validate email format
validate_email() {
    local email="$1"
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ ! "$email" =~ $email_regex ]]; then
        log_error "Invalid email format: $email"
        return 1
    fi
    return 0
}

# Validate Azure subscription ID format
validate_subscription_id() {
    local subscription_id="$1"
    local sub_regex="^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$"
    
    if [[ ! "$subscription_id" =~ $sub_regex ]]; then
        log_error "Invalid subscription ID format"
        return 1
    fi
    return 0
}

# Validate resource name (alphanumeric, hyphens, underscores)
validate_resource_name() {
    local name="$1"
    local name_regex="^[a-zA-Z0-9_-]+$"
    
    if [[ ! "$name" =~ $name_regex ]]; then
        log_error "Invalid resource name format: $name"
        return 1
    fi
    return 0
}

# Validate CIDR notation
validate_cidr() {
    local cidr="$1"
    local cidr_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$"
    
    if [[ ! "$cidr" =~ $cidr_regex ]]; then
        log_error "Invalid CIDR notation: $cidr"
        return 1
    fi
    return 0
}

# Check required environment variables
check_required_env_vars() {
    local missing_vars=()
    
    for var in "$@"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    return 0
}

# Validate file exists and is readable
validate_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "File not readable: $file"
        return 1
    fi
    return 0
}

# Validate directory exists and is writable
validate_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        log_error "Directory not found: $dir"
        return 1
    fi
    
    if [[ ! -w "$dir" ]]; then
        log_error "Directory not writable: $dir"
        return 1
    fi
    return 0
}

# Check if required commands are available
check_dependencies() {
    local missing_deps=()
    
    for cmd in az gh jq terraform; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    return 0
}

# Validate password complexity
validate_password() {
    local password="$1"
    local min_length=12
    
    if [[ ${#password} -lt $min_length ]]; then
        log_error "Password must be at least $min_length characters long"
        return 1
    fi
    
    if [[ ! "$password" =~ [A-Z] ]]; then
        log_error "Password must contain at least one uppercase letter"
        return 1
    fi
    
    if [[ ! "$password" =~ [a-z] ]]; then
        log_error "Password must contain at least one lowercase letter"
        return 1
    fi
    
    if [[ ! "$password" =~ [0-9] ]]; then
        log_error "Password must contain at least one number"
        return 1
    fi
    
    if [[ ! "$password" =~ [^[:alnum:]] ]]; then
        log_error "Password must contain at least one special character"
        return 1
    fi
    
    return 0
}
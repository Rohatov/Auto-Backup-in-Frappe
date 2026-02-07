#!/bin/bash
# ============================================
# Utility Functions for Frappe Backup System
# ============================================

# Colors for terminal output (only set if not already defined)
if [[ -z "${_UTILS_LOADED:-}" ]]; then
    readonly _UTILS_LOADED=1
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
fi

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Logging functions
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[${timestamp}] [INFO] $1"
    echo -e "${BLUE}${message}${NC}"
    if [[ -n "${LOG_FILE:-}" ]] && [[ -w "${LOG_FILE}" || -w "$(dirname "${LOG_FILE}" 2>/dev/null)" ]]; then
        echo "${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[${timestamp}] [SUCCESS] $1"
    echo -e "${GREEN}${message}${NC}"
    if [[ -n "${LOG_FILE:-}" ]] && [[ -w "${LOG_FILE}" || -w "$(dirname "${LOG_FILE}" 2>/dev/null)" ]]; then
        echo "${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[${timestamp}] [WARNING] $1"
    echo -e "${YELLOW}${message}${NC}"
    if [[ -n "${LOG_FILE:-}" ]] && [[ -w "${LOG_FILE}" || -w "$(dirname "${LOG_FILE}" 2>/dev/null)" ]]; then
        echo "${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[${timestamp}] [ERROR] $1"
    echo -e "${RED}${message}${NC}" >&2
    if [[ -n "${LOG_FILE:-}" ]] && [[ -w "${LOG_FILE}" || -w "$(dirname "${LOG_FILE}" 2>/dev/null)" ]]; then
        echo "${message}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

# Load environment configuration
load_env() {
    local env_file="$1"
    
    if [[ ! -f "${env_file}" ]]; then
        log_error "Configuration file not found: ${env_file}"
        return 1
    fi
    
    # Read .env file, skip comments and empty lines
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip comments and empty lines
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
        
        # Parse key=value
        if [[ "${line}" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove leading/trailing whitespace
            key=$(echo "${key}" | xargs)
            value=$(echo "${value}" | xargs | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            
            # Export variable
            export "${key}=${value}"
        fi
    done < "${env_file}"
    
    return 0
}

# Validate required configuration
validate_config() {
    local missing=()
    
    [[ -z "${FRAPPE_BENCH_PATH:-}" ]] && missing+=("FRAPPE_BENCH_PATH")
    [[ -z "${SITE_NAME:-}" ]] && missing+=("SITE_NAME")
    [[ -z "${BACKUP_DIR:-}" ]] && missing+=("BACKUP_DIR")
    [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] && missing+=("TELEGRAM_BOT_TOKEN")
    [[ -z "${TELEGRAM_CHAT_ID:-}" ]] && missing+=("TELEGRAM_CHAT_ID")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required configuration: ${missing[*]}"
        return 1
    fi
    
    # Validate paths
    if [[ ! -d "${FRAPPE_BENCH_PATH}" ]]; then
        log_error "Frappe bench path does not exist: ${FRAPPE_BENCH_PATH}"
        return 1
    fi
    
    return 0
}

# Check required dependencies
check_dependencies() {
    local deps=("curl" "gzip" "bench")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Create directory if not exists with proper permissions
ensure_directory() {
    local dir="$1"
    local permissions="${2:-700}"
    
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
        chmod "${permissions}" "${dir}"
        log_info "Created directory: ${dir}"
    fi
}

# Get human-readable file size
get_file_size() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        du -h "${file}" | cut -f1
    else
        echo "0"
    fi
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [[ ${bytes} -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ ${bytes} -lt 1048576 ]]; then
        echo "$((bytes / 1024))KB"
    elif [[ ${bytes} -lt 1073741824 ]]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

#!/bin/bash
# ============================================
# Frappe Backup Runner - Main Orchestrator
# ============================================
# Usage: ./backup_runner.sh [--dry-run] [--config /path/to/.env]

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Source modules
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/backup.sh"
source "${SCRIPT_DIR}/telegram.sh"

# Default configuration
DRY_RUN=false
CONFIG_FILE="${PROJECT_DIR}/.env"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help message
show_help() {
    cat << EOF
Frappe Auto-Backup System

Usage: $(basename "$0") [OPTIONS]

Options:
    --dry-run       Run without making actual changes
    --config FILE   Path to .env configuration file (default: .env)
    --help, -h      Show this help message

Examples:
    $(basename "$0")                          # Run backup with default config
    $(basename "$0") --dry-run                # Test without making changes
    $(basename "$0") --config /etc/backup.env # Use custom config file

EOF
}

# Main backup process
main() {
    local start_time=$(date +%s)
    local backup_file=""
    local exit_code=0
    
    echo "============================================"
    echo " Frappe Auto-Backup System"
    echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi
    
    # Step 1: Load configuration
    log_info "Loading configuration from: ${CONFIG_FILE}"
    if ! load_env "${CONFIG_FILE}"; then
        log_error "Failed to load configuration"
        exit 1
    fi
    
    # Step 2: Validate configuration
    log_info "Validating configuration..."
    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi
    
    # Initialize log file directory
    if [[ -n "${LOG_FILE:-}" ]]; then
        ensure_directory "$(dirname "${LOG_FILE}")" "755"
    fi
    
    log_success "Configuration validated successfully"
    log_info "Site: ${SITE_NAME}"
    log_info "Bench: ${FRAPPE_BENCH_PATH}"
    log_info "Backup Dir: ${BACKUP_DIR}"
    
    # Step 3: Check dependencies (skip bench check in dry-run if not available)
    if [[ "${DRY_RUN}" != "true" ]]; then
        log_info "Checking dependencies..."
        if ! check_dependencies; then
            log_error "Dependency check failed"
            exit 1
        fi
    fi
    
    # Step 4: Test Telegram connection
    log_info "Testing Telegram connection..."
    if ! test_telegram_connection "${DRY_RUN}"; then
        log_error "Telegram connection test failed"
        exit 1
    fi
    
    # Step 5: Create FULL backup (database + files + private-files)
    log_info "Creating FULL backup (database + files + private-files)..."
    
    # Read backup files into array
    local backup_files=()
    while IFS= read -r file; do
        [[ -n "${file}" ]] && backup_files+=("${file}")
    done < <(create_backup "${DRY_RUN}")
    
    local backup_status=$?
    
    if [[ ${backup_status} -ne 0 || ${#backup_files[@]} -eq 0 ]]; then
        log_error "Backup creation failed"
        send_backup_notification "failure" "${SITE_NAME}" "" "Backup creation failed" "${DRY_RUN}"
        exit 1
    fi
    
    log_success "Created ${#backup_files[@]} backup file(s)"
    
    # Step 6: Upload ALL backup files to Telegram
    log_info "Uploading ${#backup_files[@]} backup file(s) to Telegram..."
    
    local upload_success=true
    local uploaded_count=0
    local total_size=0
    
    for backup_file in "${backup_files[@]}"; do
        local file_type="unknown"
        if [[ "${backup_file}" == *"database"* ]]; then
            file_type="📊 Database"
        elif [[ "${backup_file}" == *"private-files"* ]]; then
            file_type="🔐 Private Files"
        elif [[ "${backup_file}" == *"files"* ]]; then
            file_type="📁 Files"
        fi
        
        local caption="${file_type}
🗄 Frappe Backup
📅 $(date '+%Y-%m-%d %H:%M')
🌐 ${SITE_NAME}
📊 $(get_file_size "${backup_file}")"
        
        log_info "Uploading: $(basename "${backup_file}")"
        
        if send_file "${backup_file}" "${caption}" "${DRY_RUN}"; then
            uploaded_count=$((uploaded_count + 1))
        else
            log_error "Failed to upload: $(basename "${backup_file}")"
            upload_success=false
        fi
    done
    
    # Send final notification
    if [[ "${upload_success}" == "true" ]]; then
        log_success "All ${uploaded_count} backup file(s) uploaded successfully"
        send_backup_notification "success" "${SITE_NAME}" "${backup_files[0]}" "" "${DRY_RUN}"
    else
        log_error "Some backup files failed to upload (${uploaded_count}/${#backup_files[@]} succeeded)"
        send_backup_notification "failure" "${SITE_NAME}" "" "Telegram upload partially failed" "${DRY_RUN}"
        exit_code=1
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "============================================"
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "Backup completed successfully in ${duration} seconds"
    else
        log_error "Backup completed with errors in ${duration} seconds"
    fi
    echo "============================================"
    
    # Show backup statistics
    echo ""
    get_backup_stats
    
    exit ${exit_code}
}

# Run main function
parse_args "$@"
main

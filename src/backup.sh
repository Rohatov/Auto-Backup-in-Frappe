#!/bin/bash
# ============================================
# Frappe Full Backup Module
# ============================================
# Creates complete backup: database + files + private-files

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Create full Frappe backup (database + files + private-files)
# Outputs backup file paths to stdout (one per line), all logs go to stderr
create_backup() {
    local dry_run="${1:-false}"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_prefix="${SITE_NAME}_${timestamp}"
    
    log_info "Starting FULL backup for site: ${SITE_NAME}" >&2
    log_info "This includes: database, files, and private-files" >&2
    
    # Ensure backup directory exists
    ensure_directory "${BACKUP_DIR}" >&2
    
    if [[ "${dry_run}" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: bench --site ${SITE_NAME} backup --with-files" >&2
        # Return dummy paths for dry-run
        echo "${BACKUP_DIR}/${backup_prefix}_database.sql.gz"
        echo "${BACKUP_DIR}/${backup_prefix}_files.tar"
        echo "${BACKUP_DIR}/${backup_prefix}_private-files.tar"
        return 0
    fi
    
    # Change to bench directory
    cd "${FRAPPE_BENCH_PATH}" || {
        log_error "Failed to change to bench directory: ${FRAPPE_BENCH_PATH}" >&2
        return 1
    }
    
    # Execute bench backup command with files
    log_info "Executing bench backup --with-files..." >&2
    local backup_output
    backup_output=$(bench --site "${SITE_NAME}" backup --with-files 2>&1)
    local backup_status=$?
    
    if [[ ${backup_status} -ne 0 ]]; then
        log_error "Backup command failed: ${backup_output}" >&2
        return 1
    fi
    
    log_info "Backup command completed successfully" >&2
    
    # Find the latest backup files
    local site_backup_dir="${FRAPPE_BENCH_PATH}/sites/${SITE_NAME}/private/backups"
    
    if [[ ! -d "${site_backup_dir}" ]]; then
        log_error "Backup directory not found: ${site_backup_dir}" >&2
        return 1
    fi
    
    # Get the most recent backup files (within last 5 minutes)
    local latest_db=$(ls -t "${site_backup_dir}"/*-database.sql.gz 2>/dev/null | head -n1)
    local latest_files=$(ls -t "${site_backup_dir}"/*-files.tar 2>/dev/null | head -n1)
    local latest_private=$(ls -t "${site_backup_dir}"/*-private-files.tar 2>/dev/null | head -n1)
    
    # Validate database backup (required)
    if [[ -z "${latest_db}" || ! -f "${latest_db}" ]]; then
        log_error "Database backup not found in: ${site_backup_dir}" >&2
        return 1
    fi
    
    # Copy database backup
    local final_db="${BACKUP_DIR}/${backup_prefix}_database.sql.gz"
    cp "${latest_db}" "${final_db}"
    chmod 600 "${final_db}"
    log_success "Database backup: ${final_db} ($(get_file_size "${final_db}"))" >&2
    echo "${final_db}"
    
    # Copy files backup (if exists)
    if [[ -n "${latest_files}" && -f "${latest_files}" ]]; then
        local final_files="${BACKUP_DIR}/${backup_prefix}_files.tar"
        cp "${latest_files}" "${final_files}"
        chmod 600 "${final_files}"
        log_success "Files backup: ${final_files} ($(get_file_size "${final_files}"))" >&2
        echo "${final_files}"
    else
        log_warning "Files backup not found (site may have no uploaded files)" >&2
    fi
    
    # Copy private-files backup (if exists)
    if [[ -n "${latest_private}" && -f "${latest_private}" ]]; then
        local final_private="${BACKUP_DIR}/${backup_prefix}_private-files.tar"
        cp "${latest_private}" "${final_private}"
        chmod 600 "${final_private}"
        log_success "Private files backup: ${final_private} ($(get_file_size "${final_private}"))" >&2
        echo "${final_private}"
    else
        log_warning "Private files backup not found (site may have no private files)" >&2
    fi
    
    return 0
}

# Get backup statistics
get_backup_stats() {
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        echo "No backups found"
        return 0
    fi
    
    local db_count=$(find "${BACKUP_DIR}" -name "*_database.sql.gz" -type f 2>/dev/null | wc -l)
    local files_count=$(find "${BACKUP_DIR}" -name "*_files.tar" -type f 2>/dev/null | wc -l)
    local private_count=$(find "${BACKUP_DIR}" -name "*_private-files.tar" -type f 2>/dev/null | wc -l)
    local total_size=$(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)
    
    echo "Backup Statistics:"
    echo "  Database backups: ${db_count}"
    echo "  Files backups: ${files_count}"
    echo "  Private files backups: ${private_count}"
    echo "  Total size: ${total_size:-0}"
    
    if [[ ${db_count} -gt 0 ]]; then
        local newest=$(ls -t "${BACKUP_DIR}"/*_database.sql.gz 2>/dev/null | head -n1)
        [[ -n "${newest}" ]] && echo "  Latest: $(basename "${newest}")"
    fi
    
    return 0
}

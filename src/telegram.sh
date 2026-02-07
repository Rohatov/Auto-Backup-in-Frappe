#!/bin/bash
# ============================================
# Telegram Bot Integration Module
# ============================================

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Telegram API base URL
readonly TELEGRAM_API="https://api.telegram.org/bot"

# Maximum retries for API calls
readonly MAX_RETRIES=3

# Send a text message to Telegram
send_message() {
    local message="$1"
    local parse_mode="${2:-HTML}"
    local dry_run="${3:-false}"
    
    if [[ "${dry_run}" == "true" ]]; then
        log_info "[DRY-RUN] Would send message: ${message}"
        return 0
    fi
    
    local url="${TELEGRAM_API}${TELEGRAM_BOT_TOKEN}/sendMessage"
    local retry=0
    local wait_time=1
    
    while [[ ${retry} -lt ${MAX_RETRIES} ]]; do
        local response
        response=$(curl -s -X POST "${url}" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=${parse_mode}" \
            --connect-timeout 30 \
            --max-time 60)
        
        # Check if request was successful
        if echo "${response}" | grep -q '"ok":true'; then
            log_success "Message sent to Telegram"
            return 0
        fi
        
        local error_desc=$(echo "${response}" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        log_warning "Telegram API error (attempt $((retry + 1))/${MAX_RETRIES}): ${error_desc}"
        
        ((retry++))
        if [[ ${retry} -lt ${MAX_RETRIES} ]]; then
            log_info "Retrying in ${wait_time} seconds..."
            sleep ${wait_time}
            wait_time=$((wait_time * 2))  # Exponential backoff
        fi
    done
    
    log_error "Failed to send message after ${MAX_RETRIES} attempts"
    return 1
}

# Send a file to Telegram
send_file() {
    local file_path="$1"
    local caption="${2:-}"
    local dry_run="${3:-false}"
    
    # Check dry-run first
    if [[ "${dry_run}" == "true" ]]; then
        log_info "[DRY-RUN] Would send file: ${file_path}"
        return 0
    fi
    
    if [[ ! -f "${file_path}" ]]; then
        log_error "File not found: ${file_path}"
        return 1
    fi
    
    local file_size=$(stat -c%s "${file_path}" 2>/dev/null || stat -f%z "${file_path}" 2>/dev/null)
    local file_name=$(basename "${file_path}")
    local max_size=$((50 * 1024 * 1024))  # 50MB limit for Telegram Bot API
    
    if [[ ${file_size} -gt ${max_size} ]]; then
        log_error "File too large for Telegram (${file_size} bytes > 50MB limit)"
        return 1
    fi
    
    log_info "Uploading file: ${file_name} ($(format_bytes ${file_size}))"
    
    local url="${TELEGRAM_API}${TELEGRAM_BOT_TOKEN}/sendDocument"
    local retry=0
    local wait_time=2
    
    while [[ ${retry} -lt ${MAX_RETRIES} ]]; do
        local response
        response=$(curl -s -X POST "${url}" \
            -F "chat_id=${TELEGRAM_CHAT_ID}" \
            -F "document=@${file_path}" \
            -F "caption=${caption}" \
            -F "parse_mode=HTML" \
            --connect-timeout 60 \
            --max-time 300)
        
        # Check if request was successful
        if echo "${response}" | grep -q '"ok":true'; then
            log_success "File uploaded to Telegram: ${file_name}"
            return 0
        fi
        
        local error_desc=$(echo "${response}" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        log_warning "Telegram upload error (attempt $((retry + 1))/${MAX_RETRIES}): ${error_desc}"
        
        ((retry++))
        if [[ ${retry} -lt ${MAX_RETRIES} ]]; then
            log_info "Retrying in ${wait_time} seconds..."
            sleep ${wait_time}
            wait_time=$((wait_time * 2))  # Exponential backoff
        fi
    done
    
    log_error "Failed to upload file after ${MAX_RETRIES} attempts"
    return 1
}

# Send backup notification
send_backup_notification() {
    local status="$1"
    local site_name="$2"
    local backup_file="${3:-}"
    local error_message="${4:-}"
    local dry_run="${5:-false}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)
    local message=""
    
    if [[ "${status}" == "success" ]]; then
        local file_size=""
        if [[ -n "${backup_file}" && -f "${backup_file}" ]]; then
            file_size=$(get_file_size "${backup_file}")
        fi
        
        message="✅ <b>Backup Successful</b>

🖥 <b>Server:</b> ${hostname}
🌐 <b>Site:</b> ${site_name}
📁 <b>File:</b> $(basename "${backup_file:-N/A}")
📊 <b>Size:</b> ${file_size:-N/A}
🕐 <b>Time:</b> ${timestamp}"
    else
        message="❌ <b>Backup Failed</b>

🖥 <b>Server:</b> ${hostname}
🌐 <b>Site:</b> ${site_name}
⚠️ <b>Error:</b> ${error_message}
🕐 <b>Time:</b> ${timestamp}"
    fi
    
    send_message "${message}" "HTML" "${dry_run}"
}

# Test Telegram connection
test_telegram_connection() {
    local dry_run="${1:-false}"
    
    log_info "Testing Telegram connection..."
    
    if [[ "${dry_run}" == "true" ]]; then
        log_info "[DRY-RUN] Would test Telegram connection"
        return 0
    fi
    
    local url="${TELEGRAM_API}${TELEGRAM_BOT_TOKEN}/getMe"
    local response
    response=$(curl -s -X GET "${url}" --connect-timeout 10)
    
    if echo "${response}" | grep -q '"ok":true'; then
        local bot_name=$(echo "${response}" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        log_success "Telegram connection OK (Bot: @${bot_name})"
        return 0
    else
        local error_desc=$(echo "${response}" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        log_error "Telegram connection failed: ${error_desc}"
        return 1
    fi
}

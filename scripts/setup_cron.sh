#!/bin/bash
# ============================================
# Cron Setup Script for Frappe Auto-Backup
# ============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
BACKUP_SCRIPT="${PROJECT_DIR}/src/backup_runner.sh"

echo "============================================"
echo " Frappe Auto-Backup Cron Setup"
echo "============================================"
echo ""

# Default schedule: 23:55 daily
DEFAULT_HOUR="17"
DEFAULT_MINUTE="01"

# Parse arguments
BACKUP_HOUR="${1:-$DEFAULT_HOUR}"
BACKUP_MINUTE="${2:-$DEFAULT_MINUTE}"

# Validate hour and minute
if ! [[ "${BACKUP_HOUR}" =~ ^[0-9]+$ ]] || [[ ${BACKUP_HOUR} -gt 23 ]]; then
    echo -e "${RED}Invalid hour: ${BACKUP_HOUR} (must be 0-23)${NC}"
    exit 1
fi

if ! [[ "${BACKUP_MINUTE}" =~ ^[0-9]+$ ]] || [[ ${BACKUP_MINUTE} -gt 59 ]]; then
    echo -e "${RED}Invalid minute: ${BACKUP_MINUTE} (must be 0-59)${NC}"
    exit 1
fi

# Check if backup script exists and is executable
if [[ ! -x "${BACKUP_SCRIPT}" ]]; then
    echo -e "${RED}Backup script not found or not executable: ${BACKUP_SCRIPT}${NC}"
    echo "Please run install.sh first."
    exit 1
fi

# Check if .env exists
if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
    echo -e "${RED}.env configuration file not found${NC}"
    echo "Please create .env from .env.example and configure it."
    exit 1
fi

# Create cron entry with log in project directory
CRON_LOG="${PROJECT_DIR}/crontab.log"
CRON_ENTRY="${BACKUP_MINUTE} ${BACKUP_HOUR} * * * ${BACKUP_SCRIPT} >> ${CRON_LOG} 2>&1"

echo -e "${YELLOW}Proposed cron schedule:${NC}"
echo "  Time: ${BACKUP_HOUR}:$(printf '%02d' ${BACKUP_MINUTE}) daily"
echo "  Entry: ${CRON_ENTRY}"
echo ""

# Check for existing entry
EXISTING=$(crontab -l 2>/dev/null | grep -F "${BACKUP_SCRIPT}" || true)

if [[ -n "${EXISTING}" ]]; then
    echo -e "${YELLOW}Existing cron entry found:${NC}"
    echo "  ${EXISTING}"
    echo ""
    read -p "Replace with new schedule? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled. No changes made."
        exit 0
    fi
    # Remove existing entry
    (crontab -l 2>/dev/null | grep -v -F "${BACKUP_SCRIPT}") | crontab -
fi

# Add new cron entry
(crontab -l 2>/dev/null; echo "${CRON_ENTRY}") | crontab -

echo ""
echo -e "${GREEN}✓ Cron job installed successfully!${NC}"
echo ""
echo "Backup will run daily at ${BACKUP_HOUR}:$(printf '%02d' ${BACKUP_MINUTE})"
echo ""
echo "To verify, run: crontab -l"
echo "To remove, run: crontab -e (and delete the line)"
echo ""

# Create log file with proper permissions if it doesn't exist
LOG_FILE="/var/log/frappe-backup-cron.log"
if [[ ! -f "${LOG_FILE}" ]] && [[ -w "/var/log" ]]; then
    sudo touch "${LOG_FILE}" 2>/dev/null || true
    sudo chmod 666 "${LOG_FILE}" 2>/dev/null || true
fi

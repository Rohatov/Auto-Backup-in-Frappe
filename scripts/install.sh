#!/bin/bash
# ============================================
# Installation Script for Frappe Auto-Backup
# ============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

echo "============================================"
echo " Frappe Auto-Backup Installation"
echo "============================================"
echo ""

# Check for required dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

check_dep() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ✓ $1 found"
        return 0
    else
        echo -e "  ${RED}✗ $1 not found${NC}"
        return 1
    fi
}

deps_ok=true
check_dep "bash" || deps_ok=false
check_dep "curl" || deps_ok=false
check_dep "gzip" || deps_ok=false

if [[ "${deps_ok}" != "true" ]]; then
    echo ""
    echo -e "${RED}Missing dependencies. Please install them and try again.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All dependencies satisfied.${NC}"
echo ""

# Set executable permissions
echo -e "${YELLOW}Setting executable permissions...${NC}"
chmod +x "${PROJECT_DIR}/src/"*.sh
chmod +x "${PROJECT_DIR}/scripts/"*.sh
echo -e "  ✓ Scripts are now executable"
echo ""

# Create .env from example if not exists
if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
    echo -e "${YELLOW}Creating .env configuration file...${NC}"
    cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
    chmod 600 "${PROJECT_DIR}/.env"
    echo -e "  ✓ Created .env from .env.example"
    echo -e "  ${YELLOW}⚠ Please edit .env with your actual configuration${NC}"
else
    echo -e "${GREEN}✓ .env already exists${NC}"
fi
echo ""

# Create default backup directory
DEFAULT_BACKUP_DIR="${HOME}/frappe-backups"
echo -e "${YELLOW}Creating default backup directory...${NC}"
mkdir -p "${DEFAULT_BACKUP_DIR}"
chmod 700 "${DEFAULT_BACKUP_DIR}"
echo -e "  ✓ Created: ${DEFAULT_BACKUP_DIR}"
echo ""

# Installation complete
echo "============================================"
echo -e "${GREEN}Installation complete!${NC}"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your configuration:"
echo "     nano ${PROJECT_DIR}/.env"
echo ""
echo "  2. Test the backup (dry-run):"
echo "     ${PROJECT_DIR}/src/backup_runner.sh --dry-run"
echo ""
echo "  3. Set up cron for daily backups:"
echo "     ${PROJECT_DIR}/scripts/setup_cron.sh"
echo ""

#!/bin/bash
#
# BindPlane Config Manager with loadCredentialEncrypted
# 
# Description: 
#   Systemd calls bindplane-config-manager_v2.sh from /etc/systemd/system/bindplane.service at Bindplane startup and uses loadCredentialEncrypted to decrypt and provide the vault key.
# Author: Olu Lawrence
# Date: December 15, 2025

set -e

# Configuration
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=/etc/bindplane
ANSIBLE_PROJECT_DIR="$ACTUAL_HOME/bindplane-config"
PLAYBOOK_FILE="deploy_bindplane.yml"
CONFIG_DESTINATION="/etc/bindplane/config.yaml"
TEMP_VAULT_PASS="/tmp/.bindplane_vault_$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Cleanup temp password file
cleanup_temp() {
    if [ -f "$TEMP_VAULT_PASS" ]; then
        shred -u "$TEMP_VAULT_PASS" 2>/dev/null || rm -f "$TEMP_VAULT_PASS"
    fi
}

trap cleanup_temp EXIT

# Function to prepare config
prepare_config() {
    log_info "Preparing Bindplane configuration..."

# Check prerequisites
    if [ ! -d "$ANSIBLE_PROJECT_DIR" ]; then
        log_error "Ansible project not found at: $ANSIBLE_PROJECT_DIR"
        exit 1
    fi

    # Check if the credentials directory is available (set by systemd LoadCredentialEncrypted)
    if [ -z "$CREDENTIALS_DIRECTORY" ] || [ ! -d "$CREDENTIALS_DIRECTORY" ]; then
        log_error "CREDENTIALS_DIRECTORY not available. Ensure the script is run via a systemd service with LoadCredentialEncrypted configured."
        exit 1
    fi

    # The password will be in a file named 'ansible_vault_key' within the CREDENTIALS_DIRECTORY
    VAULT_CRED_PATH=$(cat "$CREDENTIALS_DIRECTORY/ansible_vault_key")

    # Create temporary password file using the content from the systemd credential
    echo "$VAULT_CRED_PATH" > "$TEMP_VAULT_PASS"
    unset VAULT_PASSWORD
    chmod 600 "$TEMP_VAULT_PASS"

    log_info "Temporary vault password file created."

    # Generate config
    log_info "Decrypting passwords and generating config..."
    cd "$ANSIBLE_PROJECT_DIR"

    if ! su - $ACTUAL_USER -c "cd $ANSIBLE_PROJECT_DIR && ansible-playbook $PLAYBOOK_FILE --vault-password-file $TEMP_VAULT_PASS" > /var/log/bindplane-deploy.log 2>&1; then

        log_error "Failed to generate config. Check /var/log/bindplane-deploy.log"
        cleanup_temp
        exit 1
    fi

    # Deploy config
    if [ ! -f "$ANSIBLE_PROJECT_DIR/output/config.yaml" ]; then
        log_error "Failed to generate config file"
        cleanup_temp
        exit 1
    fi

    log_info "Deploying config to $CONFIG_DESTINATION"
    cp "$ANSIBLE_PROJECT_DIR/output/config.yaml" "$CONFIG_DESTINATION"
    chmod 600 "$CONFIG_DESTINATION"
    chown bindplane:bindplane "$CONFIG_DESTINATION"

    # Cleanup temp files
    rm -rf "$ANSIBLE_PROJECT_DIR/output"
    cleanup_temp
	
# Cleanup temp files
    rm -rf "$ANSIBLE_PROJECT_DIR/output"
    cleanup_temp

    log_info "Config deployed successfully"
}

# Function to cleanup config
cleanup_config() {
    log_warning "Cleaning up config file..."

    if [ -f "$CONFIG_DESTINATION" ]; then
        shred -u "$CONFIG_DESTINATION" 2>/dev/null || rm -f "$CONFIG_DESTINATION"
        log_info "Config file securely removed"
    else
        log_info "Config file already removed"
    fi

    if [ -d "$ANSIBLE_PROJECT_DIR/output" ]; then
        rm -rf "$ANSIBLE_PROJECT_DIR/output"
    fi
}

# Main script logic
case "${1:-}" in
    prepare)
        prepare_config
        ;;
    cleanup)
        cleanup_config
        ;;
    *)
        log_error "Usage: $0 {prepare|cleanup}"
        exit 1
        ;;
esac	

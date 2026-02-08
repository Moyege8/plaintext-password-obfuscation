/usr/local/bin # more bindplane-config-manager.sh
#!/bin/bash
#############################################################
# BindPlane Config Manager with systemd-ask-password        #
# Prompts for password using systemd's password agent       #
# Author: Olu Lawrence                                      #
# Usage:                                                    #
#   sudo /usr/local/bin/bindplane-config-manager.sh prepare #
#   sudo /usr/local/bin/bindplane-config-manager.sh cleanup #
#############################################################

set -e

# Configuration
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=/etc/bindplane
ANSIBLE_PROJECT_DIR="$ACTUAL_HOME/bindplane-config"
PLAYBOOK_FILE="deploy_bindplane.yml"
CONFIG_DESTINATION="/etc/bindplane/config.yaml"
TEMP_VAULT_PASS="/tmp/.bindplane_vault_$$$"

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
    log_info "Preparing BindPlane configuration..."
    
    # Check prerequisites
    if [ ! -d "$ANSIBLE_PROJECT_DIR" ]; then
        log_error "Ansible project not found at: $ANSIBLE_PROJECT_DIR"
        exit 1
    fi

# Prompt for password using systemd-ask-password
    if command -v systemd-ask-password &> /dev/null; then
        log_info "Prompting for vault password..."
        VAULT_PASSWORD=$(systemd-ask-password --timeout=60 "Enter Ansible Vault password for BindPlane:")
    else
        log_error "systemd-ask-password not available"
        exit 1
    fi
    
    if [ -z "$VAULT_PASSWORD" ]; then
        log_error "No password provided"
        exit 1
    fi
    
    # Create temporary password file
    echo "$VAULT_PASSWORD" > "$TEMP_VAULT_PASS"
    chmod 600 "$TEMP_VAULT_PASS"
    unset VAULT_PASSWORD
    
    # Generate config
    log_info "Decrypting passwords and generating config..."
    cd "$ANSIBLE_PROJECT_DIR"
    
    if ! su - $ACTUAL_USER -c "cd $ANSIBLE_PROJECT_DIR && ansible-playbook $PLAYBOOK_FILE --vault-password-file $TEMP_VAULT_PASS" > /var/log/bindplane-deploy.log 2>&1 ; then
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

#!/bin/bash
# ============================================================================
# Slskd VPN Port Synchronization Wrapper
# ============================================================================
# Purpose: Automatically configure slskd with VPN-forwarded port on startup
# Version: 2.0

set -eu pipefail  # Exit on error, undefined vars, pipe failures

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly SCRIPT_NAME="[Slskd-Sync]"
readonly SYNC_FILE="/vpn-sync/forwarded_port"
readonly CONFIG_FILE="/app/slskd.yml"
readonly CONFIG_BACKUP="/app/slskd.yml.backup"
readonly HTTP_PORT="${SLSKD_PORT:-8585}"
readonly MAX_WAIT_TIME=120
readonly CHECK_INTERVAL=2

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

log_info() {
    echo "${BLUE}${SCRIPT_NAME}${NC} ${1}"
}

log_success() {
    echo "${GREEN}${SCRIPT_NAME}${NC} ✅ ${1}"
}

log_warning() {
    echo "${YELLOW}${SCRIPT_NAME}${NC} ⚠️  ${1}"
}

log_error() {
    echo "${RED}${SCRIPT_NAME}${NC} ❌ ${1}" >&2
}

# Graceful shutdown handler
cleanup() {
    log_info "Shutting down..."
    # Add any other cleanup tasks here if needed
    exit 0
}

# Wait for VPN port file with timeout
wait_for_vpn_port() {
    local wait_count=0
    
    log_info "Waiting for VPN forwarded port file (${SYNC_FILE})..."
    
    while [ ! -s "${SYNC_FILE}" ]; do
        wait_count=$((wait_count + CHECK_INTERVAL))
        
        if [ ${wait_count} -ge ${MAX_WAIT_TIME} ]; then
            log_error "Timeout after ${MAX_WAIT_TIME} seconds waiting for VPN port"
            log_warning "Starting with default configuration..."
            return 1
        fi
        
        if [ $((wait_count % 10)) -eq 0 ]; then
            log_info "Still waiting... (${wait_count}/${MAX_WAIT_TIME}s)"
        fi
        
        sleep ${CHECK_INTERVAL}
    done
    
    return 0
}

validate_port() {
    # TODO: Implement
	
    return 0
}

# Update configuration file with new port
update_config() {
    local port=$1
    local temp_file="${CONFIG_FILE}.tmp"
    
    log_info "Updating configuration with port ${port}..."
    
    # Use awk for safe YAML editing
    awk -v port="${port}" -v webport="${HTTP_PORT}" '
    BEGIN {
        in_soulseek = 0
        in_web = 0
        updated_listen = 0
        updated_web = 0
    }
    
    # Track sections
    /^soulseek:/ { in_soulseek = 1; in_web = 0 }
    /^web:/ { in_web = 1; in_soulseek = 0 }
    /^[a-zA-Z]/ && !/^  / { 
        if ($0 !~ /^soulseek:/ && $0 !~ /^web:/) {
            in_soulseek = 0
            in_web = 0
        }
    }
    
    # Update listen_port in soulseek section
    in_soulseek && /^  listen_port:/ {
        print "  listen_port: " port
        updated_listen = 1
        next
    }
    
    # Update port in web section
    in_web && /^  port:/ {
        print "  port: " webport
        updated_web = 1
        next
    }
    
    # Print unchanged lines
    { print }
    
    END {
        if (updated_listen == 0) {
            print "WARNING: listen_port not found/updated" > "/dev/stderr"
        }
        if (updated_web == 0) {
            print "INFO: web port not found (may be commented)" > "/dev/stderr"
        }
    }
    ' "${CONFIG_FILE}" > "${temp_file}"
    
    # Check if update succeeded
    if [ $? -eq 0 ] && [ -s "${temp_file}" ]; then
        mv "${temp_file}" "${CONFIG_FILE}"
        return 0
    else
        rm -f "${temp_file}"
        return 1
    fi
}

# Verify configuration changes
verify_config() {
    local port=$1
    local success=0
    
    log_info "Verifying configuration..."
    
    if grep -q "^  listen_port: ${port}" "${CONFIG_FILE}"; then
        log_success "P2P port configured: ${port}"
    else
        log_error "P2P port verification failed"
        success=1
    fi
    
    if grep -q "^  port: ${HTTP_PORT}" "${CONFIG_FILE}"; then
        log_success "Web UI port configured: ${HTTP_PORT}"
    else
        log_info "Web UI port not explicitly configured (using default)"
    fi
    
    return ${success}
}

# Show configuration diff
show_diff() {
    if command -v diff >/dev/null 2>&1; then
        log_info "Configuration changes:"
        if diff -u "${CONFIG_BACKUP}" "${CONFIG_FILE}" > /tmp/config.diff 2>/dev/null; then
            log_info "No changes made to configuration"
        else
            head -15 /tmp/config.diff | sed 's/^/  /'
        fi
    fi
}

# Main execution
main() {
    log_info "Starting port synchronization wrapper v2.0"
    
    # Check if config exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        exit 1
    fi
    
    # Wait for VPN port
    if wait_for_vpn_port; then
        PORT=$(cat "${SYNC_FILE}" 2>/dev/null || echo "")
        
        if validate_port "${PORT}"; then
            log_success "VPN port acquired: ${PORT}"
            
            # Backup original config
            cp "${CONFIG_FILE}" "${CONFIG_BACKUP}"
            log_info "Configuration backed up to ${CONFIG_BACKUP}"
            
            # Update configuration
            if update_config "${PORT}"; then
                log_success "Configuration updated successfully"
                verify_config "${PORT}"
                show_diff
            else
                log_error "Failed to update configuration, restoring backup"
                cp "${CONFIG_BACKUP}" "${CONFIG_FILE}"
            fi
        else
            log_error "Invalid port received from VPN"
        fi
    fi
    
    # Start slskd
    log_info "Starting slskd..."
    log_info "Web UI available at: http://localhost:${HTTP_PORT}"
    
    # Execute slskd
    exec /slskd/slskd
}

# ============================================================================
# ENTRY POINT
# ============================================================================

# Trap signals for clean shutdown
#trap 'log_info "Shutting down..."; exit 0' SIGTERM SIGINT

# Run main function
main "$@"

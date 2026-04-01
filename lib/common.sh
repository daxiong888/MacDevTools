#!/bin/bash
# Shared library for MacDevTools scripts
# Source this file at the beginning of each script

# Prevent multiple sourcing
if [ -n "${_MACDEVTOOLS_COMMON_LOADED:-}" ]; then
    return 0
fi
_MACDEVTOOLS_COMMON_LOADED=1

# =============================================================================
# Color Constants
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
ORANGE='\033[38;5;208m'
BOLD='\033[1m'
NC='\033[0m'  # No Color

# =============================================================================
# Status Print Functions
# =============================================================================
pass() {
    echo -e "   ${GREEN}✓${NC} $1"
}

fail() {
    echo -e "   ${RED}✗${NC} $1"
}

warn() {
    echo -e "   ${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "   ${GRAY}→${NC} $1"
}

# =============================================================================
# Platform Detection Helpers
# =============================================================================
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

get_platform() {
    uname -s
}

# =============================================================================
# Command Utilities
# =============================================================================
command_exists() {
    command -v "$1" &> /dev/null
}

require_command() {
    if ! command_exists "$1"; then
        echo -e "${RED}✗ Required command '$1' not found${NC}"
        echo "  Install with: brew install $1 (macOS) or apt install $1 (Linux)"
        exit 1
    fi
}

# =============================================================================
# Directory Utilities
# =============================================================================
# Get human-readable directory size
get_size() {
    local path="$1"
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "0B"
    else
        echo "0B"
    fi
}

# Get directory size in bytes (cross-platform)
dir_bytes() {
    local path="$1"
    if [ -d "$path" ]; then
        if is_macos; then
            du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}' || echo 0
        else
            du -sb "$path" 2>/dev/null | awk '{print $1}' || echo 0
        fi
    else
        echo 0
    fi
}

# Get human-readable directory size (alias for get_size for compatibility)
dir_human() {
    get_size "$1"
}

# Clean directory contents with size reporting
clean_dir() {
    local path="$1"
    local label="$2"
    if [ -d "$path" ]; then
        local size
        size=$(get_size "$path")
        echo "   → Cleaning $label ($size)"
        rm -rf "${path:?}"/* 2>/dev/null || true
    else
        echo "   → $label not found, skipping"
    fi
}

# =============================================================================
# Print Utilities
# =============================================================================
# Print a formatted row (for tables)
row() {
    printf "   ${GRAY}%-22s${NC} %s\n" "$1" "$2"
}

# Print section header
section() {
    echo -e "${BOLD}$1${NC}"
}

#!/bin/bash

# MacDevTools Installation Script

set -e

# Detect kernel/architecture
KERNEL_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

# Default install prefix by kernel/arch (can still be overridden by env)
if [[ -z "${PREFIX:-}" ]]; then
    case "$KERNEL_NAME" in
        Darwin)
            # Apple Silicon commonly uses /opt/homebrew, Intel uses /usr/local.
            if [[ "$ARCH_NAME" == "arm64" ]] && [[ -d "/opt/homebrew" ]]; then
                PREFIX="/opt/homebrew"
            else
                PREFIX="/usr/local"
            fi
            ;;
        Linux)
            PREFIX="/usr/local"
            ;;
        *)
            echo "Warning: unsupported kernel '$KERNEL_NAME', fallback to /usr/local"
            PREFIX="/usr/local"
            ;;
    esac
fi

BINDIR="${BINDIR:-$PREFIX/bin}"
LIBDIR="${LIBDIR:-$PREFIX/lib/shelltools}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Installing MacDevTools..."
if [[ "$KERNEL_NAME" == "Darwin" ]]; then
    echo "Platform: macOS ($ARCH_NAME)"
else
    echo "Platform: $KERNEL_NAME ($ARCH_NAME)"
fi
echo "  BINDIR  = $BINDIR"
echo "  LIBDIR  = $LIBDIR"
echo ""

# Create directories (may need sudo if PREFIX is system-wide)
mkdir -p "$BINDIR" 2>/dev/null || { echo -e "${YELLOW}⚠  mkdir failed, trying with sudo...${NC}"; sudo mkdir -p "$BINDIR"; }
mkdir -p "$LIBDIR" 2>/dev/null || sudo mkdir -p "$LIBDIR"
mkdir -p "$LIBDIR/lib" 2>/dev/null || sudo mkdir -p "$LIBDIR/lib"

# Copy scripts
install_files() {
    local dst="$1"
    cp clean_*.sh "$dst/"
    cp check_network.sh port_killer.sh dns_lookup.sh fake_busy_build.sh \
       clean_logs.sh disk_usage.sh pkg_outdated.sh ssl_check.sh \
       traceroute_wrapper.sh wifi_info.sh sysinfo.sh top_processes.sh "$dst/"
    chmod +x "$dst"/*.sh
    # Copy shared library
    cp lib/common.sh "$dst/lib/"
    chmod +x "$dst/lib/*.sh"
}

install_files "$LIBDIR" 2>/dev/null || {
    sudo cp clean_*.sh check_network.sh port_killer.sh dns_lookup.sh fake_busy_build.sh \
        clean_logs.sh disk_usage.sh pkg_outdated.sh ssl_check.sh \
        traceroute_wrapper.sh wifi_info.sh sysinfo.sh top_processes.sh "$LIBDIR/"
    sudo chmod +x "$LIBDIR"/*.sh
    sudo mkdir -p "$LIBDIR/lib"
    sudo cp lib/common.sh "$LIBDIR/lib/"
    sudo chmod +x "$LIBDIR/lib/*.sh"
}

# Install launcher (tool resolves script dir dynamically at runtime)
TOOL_LAUNCHER="$BINDIR/tool"
cp tool "$TOOL_LAUNCHER" 2>/dev/null || sudo cp tool "$TOOL_LAUNCHER"

# Set permissions
chmod +x "$TOOL_LAUNCHER" 2>/dev/null || sudo chmod +x "$TOOL_LAUNCHER"

echo -e "${GREEN}✓ MacDevTools installed successfully!${NC}"
echo ""
echo "Run 'tool' to start."
if [[ "$KERNEL_NAME" != "Darwin" ]]; then
    echo ""
    echo "💡 If '$BINDIR' is not in your PATH, add this to ~/.bashrc or ~/.profile:"
    echo "   export PATH=\"$BINDIR:\$PATH\""
fi

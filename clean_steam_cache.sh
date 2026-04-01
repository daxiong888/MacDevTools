 #!/bin/bash

# Steam Download Cache Cleanup Script
# Cleans Steam download/app/http/depot caches on macOS and Linux

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Detect platform and locate Steam directory
if is_macos; then
    STEAM_DIR="$HOME/Library/Application Support/Steam"
else
    # Linux: try common Steam paths in order
    if [ -d "$HOME/.steam/steam" ]; then
        STEAM_DIR="$HOME/.steam/steam"
    elif [ -d "$HOME/.local/share/Steam" ]; then
        STEAM_DIR="$HOME/.local/share/Steam"
    elif [ -d "$HOME/snap/steam/common/.steam/steam" ]; then
        STEAM_DIR="$HOME/snap/steam/common/.steam/steam"
    else
        STEAM_DIR="$HOME/.steam/steam"   # default guess, will fail at dir check below
    fi
fi

DOWNLOADING_DIR="$STEAM_DIR/steamapps/downloading"
APP_CACHE="$STEAM_DIR/appcache"
HTTP_CACHE="$STEAM_DIR/httpcache"
DEPOT_CACHE="$STEAM_DIR/depotcache"
LOGS_DIR="$STEAM_DIR/logs"

printf "\n🕹️  Steam Download Cache Cleanup\n"
printf "===============================\n\n"
echo "   Steam directory: $STEAM_DIR"
echo ""

# Ensure Steam is installed
if [ ! -d "$STEAM_DIR" ]; then
    fail "Steam directory not found at: $STEAM_DIR"
    if ! is_macos; then
        info "Common Linux paths tried:"
        echo "     ~/.steam/steam"
        echo "     ~/.local/share/Steam"
        echo "     ~/snap/steam/common/.steam/steam"
    fi
    echo "   Please ensure Steam is installed for this user."
    exit 1
fi

# Advise user to quit Steam before cleaning
if pgrep -f "[S]team" >/dev/null 2>&1; then
    warn "Steam appears to be running. Please quit Steam before cleaning."
    read -p "Proceed anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo "📦 Targets:"
clean_dir "$DOWNLOADING_DIR" "Steam downloading cache"
clean_dir "$APP_CACHE" "Steam app cache"
clean_dir "$HTTP_CACHE" "Steam HTTP cache"
clean_dir "$DEPOT_CACHE" "Steam depot cache"
clean_dir "$LOGS_DIR" "Steam logs (optional)"

# Remove leftover partial downloads marker files
PARTIALS=$(find "$STEAM_DIR/steamapps" -maxdepth 1 -name "*.part" 2>/dev/null || true)
if [ -n "$PARTIALS" ]; then
    info "Removing partial download markers"
    find "$STEAM_DIR/steamapps" -maxdepth 1 -name "*.part" -delete 2>/dev/null || true
fi

printf "\n✅ Steam cache cleanup complete.\n"
printf "💡 Tip: Restart Steam and resume downloads if needed.\n\n"

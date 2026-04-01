#!/bin/bash

# Homebrew Cache Cleanup Script
# Clean brew download cache and old versions

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "🍺 Homebrew Cache Cleanup Tool"
echo "=============================="

# Check if brew is installed
if ! command_exists brew; then
    fail "Error: Homebrew is not installed"
    exit 1
fi

# Show cache status before cleanup
echo ""
echo "📊 Current Cache Status:"
brew --cache
CACHE_DIR=$(brew --cache)
if [ -d "$CACHE_DIR" ]; then
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    echo "   Cache directory size: $CACHE_SIZE"
fi

echo ""
echo "🧹 Starting cleanup..."

# Clean download cache (keep latest version)
echo "   → Cleaning download cache..."
brew cleanup

# Deep clean all cache (including latest version)
echo "   → Deep cleaning all cache..."
brew cleanup -s

# Clean old versions of installed software
echo "   → Cleaning old versions..."
brew cleanup --prune=all

# Delete all files in cache directory (optional, more thorough)
if [ -d "$CACHE_DIR" ]; then
    echo "   → Emptying cache directory..."
    rm -rf "${CACHE_DIR:?}"/*
fi

# Show status after cleanup
echo ""
echo "✅ Cleanup complete!"
if [ -d "$CACHE_DIR" ]; then
    NEW_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    echo "   Cache directory size: $NEW_SIZE"
fi

echo ""
echo "💡 Tip: Run 'brew doctor' to check Homebrew health status"

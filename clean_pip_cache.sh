#!/bin/bash

# pip Cache Cleanup Script
# Clean pip download cache and temporary files

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "🐍 pip Cache Cleanup Tool"
echo "========================="

# Check if pip is installed
if ! command_exists pip3 && ! command_exists pip; then
    fail "Error: pip is not installed"
    exit 1
fi

# Prefer pip3
PIP_CMD="pip3"
if ! command_exists pip3; then
    PIP_CMD="pip"
fi

# Show cache info before cleanup
echo ""
echo "📊 Current Cache Status:"
$PIP_CMD cache info 2>/dev/null || echo "   Unable to get cache info"

# Get cache directory
CACHE_DIR=$($PIP_CMD cache dir 2>/dev/null)
if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    echo "   Cache directory: $CACHE_DIR"
    echo "   Cache size: $CACHE_SIZE"
fi

echo ""
echo "🧹 Starting cleanup..."

# Clean all pip cache
echo "   → Cleaning pip cache..."
$PIP_CMD cache purge 2>/dev/null || {
    echo "   → Using fallback method..."
    if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
        rm -rf "${CACHE_DIR:?}"/*
    fi
}

# Clean wheel cache
WHEEL_CACHE="$HOME/.cache/pip/wheels"
if [ -d "$WHEEL_CACHE" ]; then
    echo "   → Cleaning wheel cache..."
    rm -rf "${WHEEL_CACHE:?}"/*
fi

# Clean http cache
HTTP_CACHE="$HOME/.cache/pip/http"
if [ -d "$HTTP_CACHE" ]; then
    echo "   → Cleaning http cache..."
    rm -rf "${HTTP_CACHE:?}"/*
fi

# macOS specific path
MAC_CACHE="$HOME/Library/Caches/pip"
if [ -d "$MAC_CACHE" ]; then
    echo "   → Cleaning macOS pip cache..."
    rm -rf "${MAC_CACHE:?}"/*
fi

# Show status after cleanup
echo ""
echo "✅ Cleanup complete!"
$PIP_CMD cache info 2>/dev/null || echo "   Cache cleared"

echo ""
echo "💡 Tip: Run 'pip3 cache info' to check cache status"

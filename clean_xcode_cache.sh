#!/bin/bash

# Xcode Cache Cleanup Script
# Clean Xcode build cache, simulator data, etc.

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "🔨 Xcode Cache Cleanup Tool"
echo "==========================="

# Check if running on macOS
if ! is_macos; then
    fail "Error: This script only supports macOS"
    exit 1
fi

# get_size() defined in common.sh

# Show status before cleanup
echo ""
echo "📊 Current Cache Status:"

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
ARCHIVES="$HOME/Library/Developer/Xcode/Archives"
DEVICE_SUPPORT="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
WATCHOS_SUPPORT="$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
CORESIM="$HOME/Library/Developer/CoreSimulator"
XCODE_CACHE="$HOME/Library/Caches/com.apple.dt.Xcode"
SIMULATORS="$HOME/Library/Developer/CoreSimulator/Devices"

echo "   DerivedData:       $(get_size "$DERIVED_DATA")"
echo "   Archives:          $(get_size "$ARCHIVES")"
echo "   iOS DeviceSupport: $(get_size "$DEVICE_SUPPORT")"
echo "   CoreSimulator:     $(get_size "$CORESIM")"
echo "   Xcode Cache:       $(get_size "$XCODE_CACHE")"

echo ""
echo "🧹 Starting cleanup..."

# 1. Clean DerivedData (build artifacts)
if [ -d "$DERIVED_DATA" ]; then
    echo "   → Cleaning DerivedData..."
    rm -rf "${DERIVED_DATA:?}"/*
    echo "     ✅ DerivedData cleaned"
fi

# 2. Clean Xcode cache
if [ -d "$XCODE_CACHE" ]; then
    echo "   → Cleaning Xcode cache..."
    rm -rf "${XCODE_CACHE:?}"/*
    echo "     ✅ Xcode cache cleaned"
fi

# 3. Clean module cache
MODULE_CACHE="$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex"
if [ -d "$MODULE_CACHE" ]; then
    echo "   → Cleaning module cache..."
    rm -rf "$MODULE_CACHE"
    echo "     ✅ Module cache cleaned"
fi

# 4. Clean LLVM cache
LLVM_CACHE="$HOME/Library/Caches/org.llvm.clang"
if [ -d "$LLVM_CACHE" ]; then
    echo "   → Cleaning LLVM cache..."
    rm -rf "${LLVM_CACHE:?}"/*
    echo "     ✅ LLVM cache cleaned"
fi

# 5. Clean Swift Package Manager cache
SPM_CACHE="$HOME/Library/Caches/org.swift.swiftpm"
if [ -d "$SPM_CACHE" ]; then
    echo "   → Cleaning SPM cache..."
    rm -rf "${SPM_CACHE:?}"/*
    echo "     ✅ SPM cache cleaned"
fi

# 6. Clean unavailable simulators (requires xcrun)
if command_exists xcrun; then
    echo "   → Cleaning unavailable simulators..."
    xcrun simctl delete unavailable 2>/dev/null || true
    echo "     ✅ Unavailable simulators cleaned"
fi

# 7. Clean Playground cache
PLAYGROUND_CACHE="$HOME/Library/Developer/XCPGDevices"
if [ -d "$PLAYGROUND_CACHE" ]; then
    echo "   → Cleaning Playground cache..."
    rm -rf "${PLAYGROUND_CACHE:?}"/*
    echo "     ✅ Playground cache cleaned"
fi

# 8. Clean documentation cache
DOC_CACHE="$HOME/Library/Developer/Shared/Documentation/DocSets"
if [ -d "$DOC_CACHE" ]; then
    echo "   → Cleaning documentation cache..."
    rm -rf "${DOC_CACHE:?}"/*
    echo "     ✅ Documentation cache cleaned"
fi

# Optional cleanup items (require confirmation)
echo ""
echo "⚠️  Optional cleanup items (may require re-download):"
echo ""

# iOS DeviceSupport cleanup hint
if [ -d "$DEVICE_SUPPORT" ]; then
    SIZE=$(get_size "$DEVICE_SUPPORT")
    echo "   iOS DeviceSupport ($SIZE):"
    echo "   Run: rm -rf \"$DEVICE_SUPPORT\"/*"
fi

# Archives cleanup hint
if [ -d "$ARCHIVES" ]; then
    SIZE=$(get_size "$ARCHIVES")
    echo ""
    echo "   Archives ($SIZE):"
    echo "   Run: rm -rf \"$ARCHIVES\"/*"
fi

# Show status after cleanup
echo ""
echo "==========================="
echo "✅ Basic cleanup complete!"
echo ""
echo "📊 Status after cleanup:"
echo "   DerivedData:  $(get_size "$DERIVED_DATA")"
echo "   Xcode Cache:  $(get_size "$XCODE_CACHE")"

echo ""
echo "💡 Tips:"
echo "   - Restart Xcode for changes to take effect"
echo "   - First build will regenerate cache"
echo "   - To clean DeviceSupport/Archives, run the commands above manually"

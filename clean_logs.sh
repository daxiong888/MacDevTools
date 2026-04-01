#!/bin/bash

# Log File Cleanup Script
# Clean system and application log files to free up disk space

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "📋 Log File Cleanup Tool"
echo "========================"

# Color and pass/fail/warn functions defined in common.sh

PLATFORM="$(uname -s)"
TOTAL_FREED=0

# dir_bytes() and dir_human() defined in common.sh

# ── 1. Application logs (macOS: ~/Library/Logs) ──────────────────────────────

if is_macos; then
    echo ""
    echo "📁 Application Logs (~/Library/Logs):"
    LOG_DIR="$HOME/Library/Logs"
    if [ -d "$LOG_DIR" ]; then
        BEFORE=$(dir_human "$LOG_DIR")
        echo "   Size before: $BEFORE"
        find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
        find "$LOG_DIR" -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
        find "$LOG_DIR" -name "*.crash" -mtime +7 -delete 2>/dev/null || true
        find "$LOG_DIR" -empty -type d -delete 2>/dev/null || true
        AFTER=$(dir_human "$LOG_DIR")
        echo -e "   ${GREEN}✓${NC} Size after:  $AFTER"
    else
        echo "   (directory not found, skipping)"
    fi

    # ── 2. Crash reports ──────────────────────────────────────────────────────
    echo ""
    echo "💥 Crash Reports (~/Library/Logs/DiagnosticReports):"
    CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
    if [ -d "$CRASH_DIR" ]; then
        COUNT=$(find "$CRASH_DIR" -name "*.crash" -o -name "*.ips" -o -name "*.diag" 2>/dev/null | wc -l | tr -d ' ')
        echo "   Found $COUNT crash/diagnostic files"
        find "$CRASH_DIR" -name "*.crash" -delete 2>/dev/null || true
        find "$CRASH_DIR" -name "*.ips" -delete 2>/dev/null || true
        find "$CRASH_DIR" -name "*.diag" -delete 2>/dev/null || true
        echo -e "   ${GREEN}✓${NC} Crash reports deleted"
    else
        echo "   (directory not found, skipping)"
    fi

    # ── 3. System diagnostic reports ─────────────────────────────────────────
    echo ""
    echo "🖥️  System Diagnostic Reports (/Library/Logs/DiagnosticReports):"
    SYS_CRASH="/Library/Logs/DiagnosticReports"
    if [ -d "$SYS_CRASH" ]; then
        COUNT=$(find "$SYS_CRASH" -name "*.crash" -o -name "*.ips" 2>/dev/null | wc -l | tr -d ' ')
        echo "   Found $COUNT files (requires sudo)"
        read -p "   Delete system crash reports? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo find "$SYS_CRASH" -name "*.crash" -delete 2>/dev/null || true
            sudo find "$SYS_CRASH" -name "*.ips" -delete 2>/dev/null || true
            echo -e "   ${GREEN}✓${NC} System crash reports deleted"
        else
            echo "   Skipped"
        fi
    else
        echo "   (directory not found, skipping)"
    fi

    # ── 4. Console logs ───────────────────────────────────────────────────────
    echo ""
    echo "🖥️  Console / System Logs:"
    # Clean asl logs
    ASL_DIR="/private/var/log/asl"
    if [ -d "$ASL_DIR" ]; then
        echo "   → Flushing old ASL logs (requires sudo)..."
        sudo aslmanager 2>/dev/null || true
        echo -e "   ${GREEN}✓${NC} ASL logs flushed"
    fi
fi

# ── 5. /var/log (Linux + macOS) ───────────────────────────────────────────────

echo ""
echo "📂 System Log Directory (/var/log):"
if [ -d "/var/log" ]; then
    VARLOG_SIZE=$(dir_human "/var/log")
    echo "   Current size: $VARLOG_SIZE"
    read -p "   Clean rotated/compressed logs in /var/log? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true
        sudo find /var/log -name "*.1" -mtime +7 -delete 2>/dev/null || true
        sudo find /var/log -name "*.old" -mtime +7 -delete 2>/dev/null || true
        NEW_SIZE=$(dir_human "/var/log")
        echo -e "   ${GREEN}✓${NC} Size after: $NEW_SIZE"
    else
        echo "   Skipped"
    fi
fi

# ── 6. ~/.cache/…/logs (common dev tool logs) ────────────────────────────────

echo ""
echo "🧰 Developer Tool Logs (~/.cache, ~/.local/share):"

dev_log_dirs=(
    "$HOME/.cache/yarn/logs"
    "$HOME/.cache/pip/log"
    "$HOME/.npm/_logs"
    "$HOME/.pnpm-state"
    "$HOME/.gradle/daemon"   # Gradle daemon logs live here
)

found_any=false
for d in "${dev_log_dirs[@]}"; do
    if [ -d "$d" ]; then
        found_any=true
        SZ=$(dir_human "$d")
        echo "   → $d ($SZ)"
        find "$d" -name "*.log" -mtime +3 -delete 2>/dev/null || true
    fi
done

if ! $found_any; then
    echo "   (no developer log directories found)"
fi

# ── 7. Xcode device logs (macOS) ─────────────────────────────────────────────

if is_macos; then
    XCODE_DEVICE_LOGS="$HOME/Library/Logs/CoreSimulator"
    echo ""
    echo "📱 iOS Simulator Logs (~/Library/Logs/CoreSimulator):"
    if [ -d "$XCODE_DEVICE_LOGS" ]; then
        SZ=$(dir_human "$XCODE_DEVICE_LOGS")
        echo "   Size: $SZ"
        read -p "   Clean simulator logs? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            find "$XCODE_DEVICE_LOGS" -name "*.log" -mtime +3 -delete 2>/dev/null || true
            find "$XCODE_DEVICE_LOGS" -name "*.logarchive" -mtime +3 -delete 2>/dev/null || true
            echo -e "   ${GREEN}✓${NC} Simulator logs cleaned"
        else
            echo "   Skipped"
        fi
    else
        echo "   (directory not found, skipping)"
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "✅ Log cleanup complete!"
echo ""
echo "💡 Tips:"
if is_macos; then
    echo "   - Open Console.app to browse live logs"
    echo "   - 'sudo log collect' captures a full diagnostic archive"
else
    echo "   - 'journalctl --disk-usage'       Show systemd journal size"
    echo "   - 'sudo journalctl --vacuum-time=7d'  Keep only last 7 days"
fi

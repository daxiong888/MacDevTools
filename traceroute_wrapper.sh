#!/bin/bash

# Traceroute Wrapper
# Run traceroute with colorized output and latency anomaly detection

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "🛤️  Traceroute Wrapper"
echo "====================="

# Color definitions in common.sh (adding ORANGE for this script)
ORANGE='\033[38;5;208m'

PLATFORM="$(uname -s)"

# Check for traceroute
if ! command_exists traceroute; then
    fail "Error: traceroute is not installed"
    if is_macos; then
        echo "   Install: traceroute comes with macOS by default"
    else
        echo "   Install: sudo apt install traceroute  or  sudo yum install traceroute"
    fi
    exit 1
fi

# ── Argument handling ─────────────────────────────────────────────────────────

HOST=""
MAX_HOPS=30
TIMEOUT=3

show_usage() {
    echo ""
    echo "Usage: tool traceroute <host> [max_hops]"
    echo ""
    echo "  host      Hostname or IP address"
    echo "  max_hops  Maximum number of hops (default: 30)"
    echo ""
    echo "Examples:"
    echo "  tool traceroute github.com"
    echo "  tool traceroute 8.8.8.8 20"
}

if [ $# -eq 0 ]; then
    read -p "Enter host to trace (hostname or IP): " -r HOST
    if [ -z "$HOST" ]; then
        echo "No host provided."
        show_usage
        exit 0
    fi
else
    HOST="$1"
    [ -n "${2:-}" ] && MAX_HOPS="$2"
fi

# Strip scheme and path (accept URLs)
HOST="${HOST#https://}"
HOST="${HOST#http://}"
HOST="${HOST%%/*}"
HOST="${HOST%%:*}"

echo ""
echo -e "${BOLD}Target: $HOST${NC}   (max hops: $MAX_HOPS)"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GRAY}Hop  IP / Hostname                      RTT      Status${NC}"
echo -e "  ${GRAY}─────────────────────────────────────────────────────────────${NC}"

# ── Run traceroute and parse output ──────────────────────────────────────────

# Run traceroute and capture output line by line
PREV_RTT=-1
REACHED=false
ANOMALY_THRESHOLD=50   # ms jump that is considered anomalous

# Build command based on platform
if is_macos; then
    TR_CMD="traceroute -n -m $MAX_HOPS -w $TIMEOUT $HOST"
else
    TR_CMD="traceroute -n -m $MAX_HOPS -w $TIMEOUT $HOST"
fi

# Run traceroute, capture all output first
TR_OUTPUT=$(eval "$TR_CMD" 2>&1)
EXIT_CODE=$?

# Parse and colorize line by line
HOP_NUM=0
while IFS= read -r line; do
    # Skip the header line
    if echo "$line" | grep -qE "^traceroute"; then
        echo -e "  ${GRAY}$line${NC}"
        continue
    fi

    # Extract hop number
    HOP_NUM=$(echo "$line" | awk '{print $1}' | tr -d ' ')
    if ! echo "$HOP_NUM" | grep -qE '^[0-9]+$'; then
        continue
    fi

    # Check for * * * (timeout / no response)
    if echo "$line" | grep -qE '^\s*[0-9]+\s+\*\s+\*\s+\*'; then
        printf "  ${GRAY}%3s${NC}  ${YELLOW}%-38s${NC}  ${YELLOW}%-8s${NC}  ${YELLOW}%s${NC}\n" \
            "$HOP_NUM" "* * *" "timeout" "⚠ no response"
        PREV_RTT=-1
        continue
    fi

    # Extract IP/hostname (field 2)
    IP=$(echo "$line" | awk '{print $2}')

    # Extract all RTT values (fields containing "ms")
    RTTS=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+' | head -3)
    if [ -z "$RTTS" ]; then
        printf "  ${GRAY}%3s${NC}  ${GRAY}%-38s${NC}  ${GRAY}%-8s${NC}  ${GRAY}%s${NC}\n" \
            "$HOP_NUM" "$IP" "?" "-"
        continue
    fi

    # Use minimum RTT of this hop
    MIN_RTT=$(echo "$RTTS" | sort -n | head -1)
    RTT_INT=${MIN_RTT%.*}

    # Determine color and status
    STATUS=""
    COLOR="$GREEN"

    if [ "$RTT_INT" -lt 20 ]; then
        COLOR="$GREEN"
        STATUS="fast"
    elif [ "$RTT_INT" -lt 80 ]; then
        COLOR="$CYAN"
        STATUS="good"
    elif [ "$RTT_INT" -lt 150 ]; then
        COLOR="$YELLOW"
        STATUS="moderate"
    elif [ "$RTT_INT" -lt 300 ]; then
        COLOR="$ORANGE"
        STATUS="slow"
    else
        COLOR="$RED"
        STATUS="very slow"
    fi

    # Anomaly detection: large jump from previous hop
    if [ "$PREV_RTT" -ge 0 ]; then
        JUMP=$(( RTT_INT - PREV_RTT ))
        if [ "$JUMP" -gt "$ANOMALY_THRESHOLD" ]; then
            COLOR="$RED"
            STATUS="⚡ spike +${JUMP}ms"
        fi
    fi

    # Check if this is the destination
    TARGET_IP=$(dig +short "$HOST" 2>/dev/null | tail -1 || true)
    if [ "$IP" = "$HOST" ] || [ "$IP" = "$TARGET_IP" ]; then
        COLOR="$GREEN"
        STATUS="✓ destination"
        REACHED=true
    fi

    printf "  ${GRAY}%3s${NC}  ${COLOR}%-38s${NC}  ${COLOR}%-8s ms${NC}  ${COLOR}%s${NC}\n" \
        "$HOP_NUM" "$IP" "$MIN_RTT" "$STATUS"

    PREV_RTT="$RTT_INT"

done <<< "$TR_OUTPUT"

echo ""
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if $REACHED; then
    echo -e "  ${GREEN}✓ Destination reached in $HOP_NUM hop(s)${NC}"
else
    echo -e "  ${YELLOW}⚠ Destination not reached within $MAX_HOPS hops${NC}"
fi

echo ""
echo "💡 Color key:"
echo -e "  ${GREEN}●${NC} < 20ms  fast       ${CYAN}●${NC} < 80ms  good"
echo -e "  ${YELLOW}●${NC} < 150ms moderate  ${ORANGE}●${NC} < 300ms slow"
echo -e "  ${RED}●${NC}  ≥ 300ms very slow  ${RED}●${NC} spike   large RTT jump"
echo ""
echo "💡 Tips:"
echo "   - * * * means the router doesn't respond to probes (not necessarily broken)"
echo "   - High RTT spikes mid-route often indicate congested peering links"
echo "   - 'tool network' for full connectivity diagnostics"

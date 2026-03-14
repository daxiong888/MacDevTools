#!/bin/bash

# Wi-Fi Information Tool
# Show current Wi-Fi connection details: SSID, BSSID, channel, band, RSSI, noise, security

set -e

echo "📶 Wi-Fi Information"
echo "===================="

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
GRAY='\033[0;90m'
NC='\033[0m'

PLATFORM="$(uname -s)"

# ── Platform guard ────────────────────────────────────────────────────────────

if [[ "$PLATFORM" != "Darwin" ]]; then
    echo ""
    echo "ℹ️  This tool currently supports macOS only."
    echo ""
    echo "On Linux, try:"
    echo "   iwconfig                    # basic Wi-Fi info"
    echo "   iw dev wlan0 link           # detailed link info"
    echo "   iw dev wlan0 station dump   # station statistics"
    echo "   nmcli device wifi           # NetworkManager Wi-Fi list"
    exit 0
fi

# ── Locate airport binary ─────────────────────────────────────────────────────

AIRPORT="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

if [ ! -x "$AIRPORT" ]; then
    echo -e "${RED}✗ airport utility not found${NC}"
    echo "  Expected: $AIRPORT"
    exit 1
fi

# ── Get Wi-Fi interface ───────────────────────────────────────────────────────

WIFI_IF=$(networksetup -listallhardwareports 2>/dev/null \
    | awk '/Wi-Fi|AirPort/{found=1} found && /Device:/{print $2; exit}')

if [ -z "$WIFI_IF" ]; then
    WIFI_IF="en0"
fi

# ── Check if Wi-Fi is on ──────────────────────────────────────────────────────

WIFI_POWER=$(networksetup -getairportpower "$WIFI_IF" 2>/dev/null | awk '{print $NF}')
if [ "$WIFI_POWER" = "Off" ]; then
    echo ""
    echo -e "${YELLOW}⚠ Wi-Fi is turned off on interface $WIFI_IF${NC}"
    echo ""
    echo "  Turn on: networksetup -setairportpower $WIFI_IF on"
    exit 0
fi

# ── Fetch airport info ────────────────────────────────────────────────────────

AIRPORT_INFO=$("$AIRPORT" -I 2>/dev/null)

if [ -z "$AIRPORT_INFO" ] || echo "$AIRPORT_INFO" | grep -q "AirPort: Off"; then
    echo ""
    echo -e "${YELLOW}⚠ Not connected to a Wi-Fi network${NC}"
    echo ""
    echo "Saved networks:"
    networksetup -listpreferredwirelessnetworks "$WIFI_IF" 2>/dev/null | head -10 || true
    exit 0
fi

# Helper: extract field from airport output
field() {
    echo "$AIRPORT_INFO" | grep -i "^\s*$1" | head -1 | awk -F': ' '{print $2}' | xargs
}

# ── Parse fields ──────────────────────────────────────────────────────────────

SSID=$(field "SSID")
BSSID=$(field "BSSID")
CHANNEL_RAW=$(field "channel")
RSSI=$(field "agrCtlRSSI")
NOISE=$(field "agrCtlNoise")
TX_RATE=$(field "lastTxRate")
MAX_RATE=$(field "maxRate")
PHY_MODE=$(field "op mode")
SECURITY=$(field "link auth")
MCS=$(field "MCS")
NSS=$(field "NSS")
GUARD=$(field "guardInterval")

# ── Parse channel and derive band ─────────────────────────────────────────────

CHANNEL_NUM=$(echo "$CHANNEL_RAW" | cut -d',' -f1 | tr -d ' ')

if [ -n "$CHANNEL_NUM" ]; then
    if [ "$CHANNEL_NUM" -le 14 ]; then
        BAND="2.4 GHz"
        BAND_COLOR="$YELLOW"
    elif [ "$CHANNEL_NUM" -le 64 ]; then
        BAND="5 GHz (UNII-1/2)"
        BAND_COLOR="$GREEN"
    elif [ "$CHANNEL_NUM" -le 144 ]; then
        BAND="5 GHz (UNII-2)"
        BAND_COLOR="$GREEN"
    elif [ "$CHANNEL_NUM" -le 196 ]; then
        BAND="5 GHz (UNII-3)"
        BAND_COLOR="$GREEN"
    else
        BAND="6 GHz (Wi-Fi 6E)"
        BAND_COLOR="$CYAN"
    fi
else
    BAND="Unknown"
    BAND_COLOR="$GRAY"
fi

# Channel width from raw string (e.g. "6,+1" → 40MHz; "6" → 20MHz; contains ",80" etc)
CHAN_WIDTH="20 MHz"
if echo "$CHANNEL_RAW" | grep -q ",80"; then
    CHAN_WIDTH="80 MHz"
elif echo "$CHANNEL_RAW" | grep -q ",160"; then
    CHAN_WIDTH="160 MHz"
elif echo "$CHANNEL_RAW" | grep -qE ",\+[0-9]|,-[0-9]"; then
    CHAN_WIDTH="40 MHz"
fi

# ── Signal quality (RSSI → percentage) ───────────────────────────────────────

signal_quality() {
    local rssi="$1"
    # Typical range: -100 dBm (worst) to -50 dBm (best)
    if [ -z "$rssi" ] || [ "$rssi" -eq 0 ]; then echo "N/A"; return; fi
    local quality=$(( (rssi + 100) * 2 ))
    [ "$quality" -lt 0 ]   && quality=0
    [ "$quality" -gt 100 ] && quality=100
    echo "${quality}%"
}

signal_bar() {
    local rssi="$1"
    local bars=""
    if   [ "$rssi" -ge -50 ]; then bars="▓▓▓▓▓ Excellent"
    elif [ "$rssi" -ge -60 ]; then bars="▓▓▓▓░ Good"
    elif [ "$rssi" -ge -70 ]; then bars="▓▓▓░░ Fair"
    elif [ "$rssi" -ge -80 ]; then bars="▓▓░░░ Weak"
    else                            bars="▓░░░░ Very Weak"
    fi
    echo "$bars"
}

signal_color() {
    local rssi="$1"
    if   [ "$rssi" -ge -60 ]; then echo "$GREEN"
    elif [ "$rssi" -ge -70 ]; then echo "$YELLOW"
    else                            echo "$RED"
    fi
}

SNR=""
if [ -n "$RSSI" ] && [ -n "$NOISE" ]; then
    SNR=$(( RSSI - NOISE ))
fi

# ── Display ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}🔗 Connection Details:${NC}"
echo -e "${GRAY}   ──────────────────────────────────────────────${NC}"

SIG_COLOR=$(signal_color "${RSSI:--100}")
SIG_QUALITY=$(signal_quality ${RSSI:-0})
SIG_BAR=$(signal_bar ${RSSI:--100})

printf "   ${GRAY}%-18s${NC} %s\n" "SSID"     "${SSID:-N/A}"
printf "   ${GRAY}%-18s${NC} %s\n" "BSSID"    "${BSSID:-N/A}"
printf "   ${GRAY}%-18s${NC} ${BAND_COLOR}%s (%s, %s)${NC}\n" \
    "Band / Channel" "$BAND" "ch $CHANNEL_NUM" "$CHAN_WIDTH"
printf "   ${GRAY}%-18s${NC} ${SIG_COLOR}%s dBm  (%s)  %s${NC}\n" \
    "Signal (RSSI)"  "${RSSI:-N/A}" "$SIG_QUALITY" "$SIG_BAR"
printf "   ${GRAY}%-18s${NC} %s dBm\n" "Noise"    "${NOISE:-N/A}"
[ -n "$SNR" ] && printf "   ${GRAY}%-18s${NC} %s dB\n" "SNR" "$SNR"
printf "   ${GRAY}%-18s${NC} %s Mbps\n" "TX Rate"  "${TX_RATE:-N/A}"
printf "   ${GRAY}%-18s${NC} %s Mbps\n" "Max Rate"  "${MAX_RATE:-N/A}"
printf "   ${GRAY}%-18s${NC} %s\n" "PHY Mode"  "${PHY_MODE:-N/A}"
printf "   ${GRAY}%-18s${NC} %s\n" "Security"  "${SECURITY:-N/A}"
[ -n "$MCS" ]    && printf "   ${GRAY}%-18s${NC} %s\n" "MCS Index" "$MCS"
[ -n "$NSS" ]    && printf "   ${GRAY}%-18s${NC} %s spatial streams\n" "Spatial Streams" "$NSS"
[ -n "$GUARD" ]  && printf "   ${GRAY}%-18s${NC} %s ns\n" "Guard Interval" "$GUARD"

# ── Interface info ────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}🖥️  Interface: $WIFI_IF${NC}"
echo -e "${GRAY}   ──────────────────────────────────────────────${NC}"

IP4=$(ipconfig getifaddr "$WIFI_IF" 2>/dev/null || true)
IP6=$(ifconfig "$WIFI_IF" 2>/dev/null | grep "inet6" | grep -v "fe80" | awk '{print $2}' | head -1 || true)
MAC=$(ifconfig "$WIFI_IF" 2>/dev/null | grep "ether" | awk '{print $2}' || true)

printf "   ${GRAY}%-18s${NC} %s\n" "IPv4 Address" "${IP4:-not assigned}"
[ -n "$IP6" ] && printf "   ${GRAY}%-18s${NC} %s\n" "IPv6 Address" "$IP6"
printf "   ${GRAY}%-18s${NC} %s\n" "MAC Address" "${MAC:-N/A}"

# ── Nearby networks ───────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}📡 Nearby Wi-Fi Networks (scan):${NC}"
echo -e "${GRAY}   ──────────────────────────────────────────────${NC}"
echo "   Scanning..."
SCAN=$("$AIRPORT" -s 2>/dev/null | tail -n +2 | sort -t' ' -k3 -rn | head -12)
if [ -n "$SCAN" ]; then
    printf "   ${GRAY}%-32s %-18s %5s  %s${NC}\n" "SSID" "BSSID" "RSSI" "CH"
    echo "$SCAN" | while IFS= read -r sline; do
        SCAN_SSID=$(echo "$sline"  | awk '{$1=$1; for(i=NF;i>=1&&$i!~/^[0-9a-f]{2}:/;i--) {}; print substr($0, 1, index($0,$i)-2)}')
        SCAN_BSSID=$(echo "$sline" | grep -oE '[0-9a-f]{2}(:[0-9a-f]{2}){5}' | head -1)
        SCAN_RSSI=$(echo "$sline"  | awk '{for(i=1;i<=NF;i++) if($i~/^-[0-9]+$/) {print $i; exit}}')
        SCAN_CH=$(echo "$sline"    | awk '{print $NF}')

        SC="$GRAY"
        [ -n "$SCAN_RSSI" ] && SC=$(signal_color "$SCAN_RSSI")

        CURRENT_MARK="  "
        [ "$SCAN_BSSID" = "$BSSID" ] && CURRENT_MARK="${GREEN}◀${NC}"

        printf "   ${SC}%-32s %-18s %5s  %-4s${NC} %b\n" \
            "${SCAN_SSID:0:31}" "${SCAN_BSSID:-?}" "${SCAN_RSSI:-?}" "${SCAN_CH:-?}" "$CURRENT_MARK"
    done
else
    echo "   (no networks found in scan)"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "💡 Tips:"
echo "   - RSSI ≥ -60 dBm: good signal;  ≤ -80 dBm: consider moving closer to AP"
echo "   - High noise floor (≤ -85 dBm) may indicate interference"
echo "   - 5 GHz / 6 GHz bands offer faster speeds but shorter range than 2.4 GHz"
echo "   - 'tool network' for full connectivity diagnostics"

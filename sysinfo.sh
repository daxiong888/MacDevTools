#!/bin/bash

# System Information Summary
# One-screen snapshot: CPU, memory, disk, GPU, battery, OS, uptime

set -e

echo "🖥️  System Information"
echo "======================"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
GRAY='\033[0;90m'
NC='\033[0m'

PLATFORM="$(uname -s)"

# Helper: print a labelled row
row() {
    printf "   ${GRAY}%-22s${NC} %s\n" "$1" "$2"
}

# ── OS Info ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}🍎 Operating System:${NC}"

if [[ "$PLATFORM" == "Darwin" ]]; then
    OS_NAME=$(sw_vers -productName 2>/dev/null)
    OS_VER=$(sw_vers -productVersion 2>/dev/null)
    OS_BUILD=$(sw_vers -buildVersion 2>/dev/null)
    row "OS" "$OS_NAME $OS_VER (Build $OS_BUILD)"
else
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        row "OS" "$PRETTY_NAME"
    else
        row "OS" "$(uname -srm)"
    fi
fi

HOSTNAME=$(hostname)
KERNEL=$(uname -r)
ARCH=$(uname -m)
row "Hostname" "$HOSTNAME"
row "Kernel" "$KERNEL  ($ARCH)"

UPTIME_RAW=$(uptime 2>/dev/null | sed 's/.*up //' | sed 's/,.*//')
row "Uptime" "$UPTIME_RAW"

# ── CPU ───────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}⚙️  CPU:${NC}"

if [[ "$PLATFORM" == "Darwin" ]]; then
    CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || \
                system_profiler SPHardwareDataType 2>/dev/null | grep "Chip\|Processor Name" | head -1 | awk -F': ' '{print $2}' | xargs)
    CPU_CORES=$(sysctl -n hw.physicalcpu 2>/dev/null)
    CPU_THREADS=$(sysctl -n hw.logicalcpu 2>/dev/null)
    CPU_FREQ=$(sysctl -n hw.cpufrequency_max 2>/dev/null | awk '{printf "%.2f GHz", $1/1e9}' 2>/dev/null || true)
    # For Apple Silicon, frequency isn't exposed via sysctl
    [ -z "$CPU_FREQ" ] && CPU_FREQ=$(system_profiler SPHardwareDataType 2>/dev/null \
        | grep -i "Processor Speed" | awk -F': ' '{print $2}' | xargs || true)
else
    CPU_BRAND=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}' | xargs)
    CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null)
    CPU_THREADS="$CPU_CORES"
    CPU_FREQ=$(grep -m1 "cpu MHz" /proc/cpuinfo 2>/dev/null | awk -F': ' '{printf "%.2f GHz", $2/1000}' || true)
fi

row "CPU" "${CPU_BRAND:-Unknown}"
row "Cores / Threads" "${CPU_CORES:-?} cores / ${CPU_THREADS:-?} threads"
[ -n "$CPU_FREQ" ] && row "Base Frequency" "$CPU_FREQ"

# CPU load averages
LOAD=$(uptime | grep -oE 'load averages?: .*' | sed 's/load averages*: //')
row "Load Average" "$LOAD"

# ── Memory ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}🧠 Memory:${NC}"

if [[ "$PLATFORM" == "Darwin" ]]; then
    TOTAL_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
    TOTAL_RAM=$(echo "$TOTAL_RAM_BYTES" | awk '{printf "%.1f GB", $1/1073741824}')

    # vm_stat for memory pressure
    VM=$(vm_stat 2>/dev/null)
    PAGE_SIZE=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)

    pages_free=$(echo "$VM"     | grep "Pages free"     | awk '{print $3}' | tr -d '.')
    pages_active=$(echo "$VM"   | grep "Pages active"   | awk '{print $3}' | tr -d '.')
    pages_inactive=$(echo "$VM" | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
    pages_wired=$(echo "$VM"    | grep "Pages wired"    | awk '{print $4}' | tr -d '.')
    pages_compr=$(echo "$VM"    | grep "Pages stored in compressor" | awk '{print $5}' | tr -d '.')

    pages_free=${pages_free:-0}
    pages_active=${pages_active:-0}
    pages_inactive=${pages_inactive:-0}
    pages_wired=${pages_wired:-0}
    pages_compr=${pages_compr:-0}

    USED_BYTES=$(( (pages_active + pages_wired + pages_compr) * PAGE_SIZE ))
    FREE_BYTES=$(( (pages_free + pages_inactive) * PAGE_SIZE ))

    USED_GB=$(echo "$USED_BYTES" | awk '{printf "%.1f GB", $1/1073741824}')
    FREE_GB=$(echo "$FREE_BYTES" | awk '{printf "%.1f GB", $1/1073741824}')

    MEM_PCT=$(echo "$USED_BYTES $TOTAL_RAM_BYTES" | awk '{printf "%d%%", ($1/$2)*100}')

    row "Total RAM" "$TOTAL_RAM"
    row "Used" "$USED_GB  ($MEM_PCT)"
    row "Available" "$FREE_GB"

    # Memory pressure color
    MEM_PCT_INT=$(echo "$USED_BYTES $TOTAL_RAM_BYTES" | awk '{printf "%d", ($1/$2)*100}')
    if [ "$MEM_PCT_INT" -lt 70 ]; then
        echo -e "   ${GREEN}✓ Memory pressure: normal${NC}"
    elif [ "$MEM_PCT_INT" -lt 85 ]; then
        echo -e "   ${YELLOW}⚠ Memory pressure: moderate (${MEM_PCT} used)${NC}"
    else
        echo -e "   ${RED}✗ Memory pressure: HIGH (${MEM_PCT} used)${NC}"
    fi

    # Swap
    SWAP_USED=$(sysctl -n vm.swapusage 2>/dev/null | grep -oE 'used = [0-9.]+M' | awk '{print $3}')
    [ -n "$SWAP_USED" ] && row "Swap Used" "$SWAP_USED"

else
    # Linux
    TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    FREE_KB=$(grep "^MemFree" /proc/meminfo | awk '{print $2}')
    USED_KB=$(( TOTAL_KB - AVAIL_KB ))

    TOTAL_GB=$(echo "$TOTAL_KB" | awk '{printf "%.1f GB", $1/1048576}')
    USED_GB=$(echo "$USED_KB"   | awk '{printf "%.1f GB", $1/1048576}')
    AVAIL_GB=$(echo "$AVAIL_KB" | awk '{printf "%.1f GB", $1/1048576}')
    MEM_PCT=$(( USED_KB * 100 / TOTAL_KB ))

    row "Total RAM" "$TOTAL_GB"
    row "Used" "$USED_GB  (${MEM_PCT}%)"
    row "Available" "$AVAIL_GB"

    SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    SWAP_FREE=$(grep SwapFree  /proc/meminfo | awk '{print $2}')
    if [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_USED_KB=$(( SWAP_TOTAL - SWAP_FREE ))
        SWAP_USED=$(echo "$SWAP_USED_KB" | awk '{printf "%.1f GB", $1/1048576}')
        SWAP_TOT=$(echo "$SWAP_TOTAL" | awk '{printf "%.1f GB", $1/1048576}')
        row "Swap" "$SWAP_USED used / $SWAP_TOT total"
    fi
fi

# ── Disk ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}💾 Storage:${NC}"

if [[ "$PLATFORM" == "Darwin" ]]; then
    df -h | grep -E "^/dev" | while IFS= read -r dline; do
        FS=$(echo "$dline"    | awk '{print $1}')
        SIZE=$(echo "$dline"  | awk '{print $2}')
        USED=$(echo "$dline"  | awk '{print $3}')
        AVAIL=$(echo "$dline" | awk '{print $4}')
        PCT=$(echo "$dline"   | awk '{print $5}')
        MNT=$(echo "$dline"   | awk '{print $9}')
        PCT_INT=${PCT/\%/}
        if [ "$PCT_INT" -ge 90 ] 2>/dev/null; then
            printf "   ${RED}%-14s %5s used / %5s total  %3s used  %s${NC}\n" \
                "$MNT" "$USED" "$SIZE" "$PCT" ""
        elif [ "$PCT_INT" -ge 75 ] 2>/dev/null; then
            printf "   ${YELLOW}%-14s %5s used / %5s total  %3s used${NC}\n" \
                "$MNT" "$USED" "$SIZE" "$PCT"
        else
            printf "   ${GREEN}%-14s${NC} %5s used / %5s total  %3s used\n" \
                "$MNT" "$USED" "$SIZE" "$PCT"
        fi
    done
else
    df -h --output=target,size,used,avail,pcent | grep -v "^Filesystem\|tmpfs\|udev" | head -8 | while IFS= read -r dline; do
        printf "   %s\n" "$dline"
    done
fi

# ── GPU ───────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}🎮 GPU:${NC}"

if [[ "$PLATFORM" == "Darwin" ]]; then
    system_profiler SPDisplaysDataType 2>/dev/null \
        | grep -E "Chipset Model|VRAM|Resolution|Metal" \
        | sed 's/^\s*//' \
        | while IFS= read -r gline; do
            KEY=$(echo "$gline" | cut -d: -f1 | xargs)
            VAL=$(echo "$gline" | cut -d: -f2- | xargs)
            row "$KEY" "$VAL"
        done
else
    if command -v lspci &>/dev/null; then
        lspci 2>/dev/null | grep -iE "VGA|3D|Display|GPU" | while IFS= read -r gline; do
            row "GPU" "$gline"
        done
    else
        row "GPU" "(lspci not available)"
    fi
fi

# ── Battery (macOS only) ──────────────────────────────────────────────────────

if [[ "$PLATFORM" == "Darwin" ]]; then
    BAT_INFO=$(system_profiler SPPowerDataType 2>/dev/null)
    if echo "$BAT_INFO" | grep -q "Cycle Count"; then
        echo ""
        echo -e "${BOLD}🔋 Battery:${NC}"

        BAT_CYCLE=$(echo "$BAT_INFO" | grep "Cycle Count"  | head -1 | awk -F': ' '{print $2}' | xargs)
        BAT_COND=$(echo "$BAT_INFO"  | grep "Condition"    | head -1 | awk -F': ' '{print $2}' | xargs)
        BAT_CAP=$(echo "$BAT_INFO"   | grep "Maximum Capacity" | head -1 | awk -F': ' '{print $2}' | xargs)
        BAT_CHARGE=$(pmset -g batt 2>/dev/null | grep -oE '[0-9]+%' | head -1)
        BAT_STATUS=$(pmset -g batt 2>/dev/null | grep -oE 'charging|discharging|charged|AC Power|Battery Power' | head -1)

        row "Charge" "${BAT_CHARGE:-N/A}  (${BAT_STATUS:-?})"
        row "Condition" "${BAT_COND:-N/A}"
        row "Max Capacity" "${BAT_CAP:-N/A}"
        row "Cycle Count" "${BAT_CYCLE:-N/A}"

        # Color-code condition
        if [ "$BAT_COND" = "Normal" ]; then
            echo -e "   ${GREEN}✓ Battery health is normal${NC}"
        elif [ -n "$BAT_COND" ]; then
            echo -e "   ${RED}✗ Battery condition: $BAT_COND — consider service${NC}"
        fi
    fi
fi

# ── Network interfaces quick summary ─────────────────────────────────────────

echo ""
echo -e "${BOLD}🌐 Active Network Interfaces:${NC}"

if [[ "$PLATFORM" == "Darwin" ]]; then
    ifconfig 2>/dev/null | awk '
        /^[a-z]/ { iface=$1 }
        /inet / && !/127.0.0.1/ { printf "   %-12s %s\n", iface, $2 }
    ' | head -6
else
    ip -4 addr 2>/dev/null | awk '
        /^[0-9]/ { split($2,a,":"); iface=a[2] }
        /inet / && !/127.0.0.1/ { printf "   %-12s %s\n", iface, $2 }
    ' | head -6
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "✅ System snapshot complete!"
echo ""
echo "💡 Tips:"
echo "   - 'tool disk'    In-depth disk usage analysis"
echo "   - 'tool topproc' Top CPU/memory processes"
if [[ "$PLATFORM" == "Darwin" ]]; then
    echo "   - 'tool wifi'    Wi-Fi signal & channel details"
fi

#!/bin/bash

# Top Processes Viewer
# Show top CPU or memory consuming processes in a formatted table

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
GRAY='\033[0;90m'
ORANGE='\033[38;5;208m'
NC='\033[0m'

PLATFORM="$(uname -s)"

# ── Defaults ──────────────────────────────────────────────────────────────────

SORT_BY="cpu"   # cpu | mem
TOP_N=15
LOOP=false
INTERVAL=3

# ── Argument parsing ──────────────────────────────────────────────────────────

show_usage() {
    echo "Usage: tool topproc [-c|-m] [-n <count>] [-w]"
    echo ""
    echo "  -c          Sort by CPU usage (default)"
    echo "  -m          Sort by memory usage"
    echo "  -n <count>  Show top N processes (default: 15)"
    echo "  -w          Watch mode: refresh every ${INTERVAL}s (Ctrl+C to quit)"
    echo ""
    echo "Examples:"
    echo "  tool topproc           # top 15 by CPU"
    echo "  tool topproc -m        # top 15 by memory"
    echo "  tool topproc -m -n 20  # top 20 by memory"
    echo "  tool topproc -w        # live watch mode"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) SORT_BY="cpu"; shift ;;
        -m) SORT_BY="mem"; shift ;;
        -n) TOP_N="${2:-15}"; shift 2 ;;
        -w) LOOP=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# ── Helper: render the table ──────────────────────────────────────────────────

render() {
    local sort_key="$1"

    if [[ "$sort_key" == "cpu" ]]; then
        SORT_COL=3
        HEADER_TAG="CPU"
    else
        SORT_COL=4
        HEADER_TAG="MEM"
    fi

    echo ""
    echo -e "${BOLD}🔥 Top $TOP_N Processes by $HEADER_TAG  $(date '+%H:%M:%S')${NC}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "${GRAY}  %-7s  %-10s  %6s  %6s  %8s  %-30s${NC}\n" \
        "PID" "USER" "%CPU" "%MEM" "VSZ(MB)" "COMMAND"
    echo -e "${GRAY}  ───────  ──────────  ──────  ──────  ────────  ──────────────────────────────${NC}"

    if [[ "$PLATFORM" == "Darwin" ]]; then
        # macOS ps: pid user %cpu %mem vsz comm
        PS_OUT=$(ps -Ao pid,user,%cpu,%mem,vsz,comm 2>/dev/null | tail -n +2 \
            | sort -k"$SORT_COL" -rn \
            | head -"$TOP_N")
    else
        PS_OUT=$(ps -eo pid,user,%cpu,%mem,vsz,comm --no-headers 2>/dev/null \
            | sort -k"$SORT_COL" -rn \
            | head -"$TOP_N")
    fi

    echo "$PS_OUT" | while IFS= read -r pline; do
        PID=$(echo  "$pline" | awk '{print $1}')
        USER=$(echo "$pline" | awk '{print $2}')
        CPU=$(echo  "$pline" | awk '{print $3}')
        MEM=$(echo  "$pline" | awk '{print $4}')
        VSZ=$(echo  "$pline" | awk '{print $5}')
        CMD=$(echo  "$pline" | awk '{print $6}')

        # Convert VSZ from KB to MB
        VSZ_MB=$(echo "$VSZ" | awk '{printf "%.0f", $1/1024}')

        # Color by metric
        CPU_INT=${CPU%.*}
        MEM_INT=${MEM%.*}

        if [ "$sort_key" = "cpu" ]; then
            if   [ "${CPU_INT:-0}" -ge 50 ]; then ROW_COLOR="$RED"
            elif [ "${CPU_INT:-0}" -ge 20 ]; then ROW_COLOR="$ORANGE"
            elif [ "${CPU_INT:-0}" -ge 5  ]; then ROW_COLOR="$YELLOW"
            else                                  ROW_COLOR="$NC"
            fi
        else
            if   [ "${MEM_INT:-0}" -ge 10 ]; then ROW_COLOR="$RED"
            elif [ "${MEM_INT:-0}" -ge 5  ]; then ROW_COLOR="$ORANGE"
            elif [ "${MEM_INT:-0}" -ge 2  ]; then ROW_COLOR="$YELLOW"
            else                                  ROW_COLOR="$NC"
            fi
        fi

        # Highlight active metric column
        if [ "$sort_key" = "cpu" ]; then
            printf "  ${ROW_COLOR}%-7s  %-10s  ${BOLD}%6s${NC}${ROW_COLOR}  %6s  %8s  %-30s${NC}\n" \
                "$PID" "${USER:0:10}" "${CPU}%" "${MEM}%" "$VSZ_MB" "${CMD:0:30}"
        else
            printf "  ${ROW_COLOR}%-7s  %-10s  %6s  ${BOLD}%6s${NC}${ROW_COLOR}  %8s  %-30s${NC}\n" \
                "$PID" "${USER:0:10}" "${CPU}%" "${MEM}%" "$VSZ_MB" "${CMD:0:30}"
        fi
    done

    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # System summary row
    if [[ "$PLATFORM" == "Darwin" ]]; then
        TOTAL_PROCS=$(ps -A 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
        CPU_IDLE=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $7}' | tr -d '%' || echo "?")
        echo -e "  ${GRAY}Total processes: $TOTAL_PROCS  |  CPU idle: ${CPU_IDLE}%${NC}"
    else
        TOTAL_PROCS=$(ps -e 2>/dev/null | wc -l | tr -d ' ')
        echo -e "  ${GRAY}Total processes: $TOTAL_PROCS${NC}"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

if $LOOP; then
    echo -e "${CYAN}Watch mode — refreshing every ${INTERVAL}s.  Press Ctrl+C to quit.${NC}"
    while true; do
        clear
        echo "⚙️  Top Processes — Watch Mode"
        echo "=============================="
        render "$SORT_BY"
        echo ""
        echo -e "  ${GRAY}Sorted by: ${BOLD}${SORT_BY^^}${NC}  |  Press ${CYAN}Ctrl+C${NC} to exit"
        sleep "$INTERVAL"
    done
else
    echo "⚙️  Top Processes"
    echo "================="
    render "$SORT_BY"
    echo ""
    echo "💡 Tips:"
    echo "   - 'tool topproc -m'    Sort by memory instead"
    echo "   - 'tool topproc -w'    Live watch mode (auto-refresh)"
    echo "   - 'tool topproc -n 25' Show more processes"
    echo "   - 'kill -9 <PID>'      Force kill a process"
    echo "   - 'tool port -l'       Check what's listening on network ports"
fi

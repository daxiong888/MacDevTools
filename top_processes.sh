#!/bin/bash

# Top Processes Viewer
# Show top CPU or memory consuming processes in a formatted table

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Color definitions in common.sh (adding ORANGE for this script)
ORANGE='\033[38;5;208m'

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
        -n)
            if [ $# -lt 2 ]; then
                echo "Error: Please specify a count after -n"
                show_usage
                exit 1
            fi
            TOP_N="${2:-15}"
            if ! [[ "$TOP_N" =~ ^[0-9]+$ ]] || [ "$TOP_N" -le 0 ]; then
                echo "Invalid count: $TOP_N"
                show_usage
                exit 1
            fi
            shift 2
            ;;
        -w) LOOP=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# ── Helper: render the table ──────────────────────────────────────────────────

render() {
    local sort_key="$1"
    local ps_out=""
    local row_color=""
    local total_procs="0"
    local cpu_idle="?"

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

    if is_macos; then
        # macOS ps: pid user %cpu %mem vsz comm
        ps_out=$(ps -Ao pid,user,%cpu,%mem,vsz,comm 2>/dev/null | tail -n +2 \
            | sort -k"$SORT_COL" -rn \
            | head -"$TOP_N" || true)
    else
        ps_out=$(ps -eo pid,user,%cpu,%mem,vsz,comm --no-headers 2>/dev/null \
            | sort -k"$SORT_COL" -rn \
            | head -"$TOP_N" || true)
    fi

    if [ -z "$ps_out" ]; then
        warn "No process data available from ps"
        echo -e "  ${GRAY}(This can happen in restricted environments.)${NC}"
    else
        while IFS= read -r pline; do
            local pid="" user="" cpu="" mem="" vsz="" cmd=""
            local vsz_mb="?"
            local cpu_int="0"
            local mem_int="0"

            [ -z "$pline" ] && continue
            read -r pid user cpu mem vsz cmd <<< "$pline"
            [ -z "$pid" ] && continue

            # Convert VSZ from KB to MB when ps returns a numeric size.
            if [[ "$vsz" =~ ^[0-9]+$ ]]; then
                vsz_mb=$(( vsz / 1024 ))
            fi

            # Color by metric
            cpu_int=${cpu%.*}
            mem_int=${mem%.*}

            if [ "$sort_key" = "cpu" ]; then
                if   [ "${cpu_int:-0}" -ge 50 ]; then row_color="$RED"
                elif [ "${cpu_int:-0}" -ge 20 ]; then row_color="$ORANGE"
                elif [ "${cpu_int:-0}" -ge 5  ]; then row_color="$YELLOW"
                else                                  row_color="$NC"
                fi
            else
                if   [ "${mem_int:-0}" -ge 10 ]; then row_color="$RED"
                elif [ "${mem_int:-0}" -ge 5  ]; then row_color="$ORANGE"
                elif [ "${mem_int:-0}" -ge 2  ]; then row_color="$YELLOW"
                else                                  row_color="$NC"
                fi
            fi

            # Highlight active metric column
            if [ "$sort_key" = "cpu" ]; then
                printf "  ${row_color}%-7s  %-10s  ${BOLD}%6s${NC}${row_color}  %6s  %8s  %-30s${NC}\n" \
                    "$pid" "${user:0:10}" "${cpu}%" "${mem}%" "$vsz_mb" "${cmd:0:30}"
            else
                printf "  ${row_color}%-7s  %-10s  %6s  ${BOLD}%6s${NC}${row_color}  %8s  %-30s${NC}\n" \
                    "$pid" "${user:0:10}" "${cpu}%" "${mem}%" "$vsz_mb" "${cmd:0:30}"
            fi
        done <<< "$ps_out"
    fi

    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # System summary row
    if is_macos; then
        total_procs=$(ps -A 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || true)
        [ -z "$total_procs" ] && total_procs=0
        cpu_idle=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $7}' | tr -d '%' || echo "?")
        echo -e "  ${GRAY}Total processes: $total_procs  |  CPU idle: ${cpu_idle}%${NC}"
    else
        total_procs=$(ps -e 2>/dev/null | wc -l | tr -d ' ' || true)
        [ -z "$total_procs" ] && total_procs=0
        echo -e "  ${GRAY}Total processes: $total_procs${NC}"
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

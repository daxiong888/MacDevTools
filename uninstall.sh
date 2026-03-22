#!/bin/bash

set -euo pipefail

# MacDevTools Uninstallation Script

PREFIX="${PREFIX:-/usr/local}"
BINDIR="${BINDIR:-$PREFIX/bin}"
LIBDIR="${LIBDIR:-$PREFIX/lib/shelltools}"

MODE="all" # all | brew | manual
UNTAP=false

usage() {
	cat <<EOF
Usage: ./uninstall.sh [--brew|--manual|--all] [--untap] [--help]

Options:
  --brew      Uninstall Homebrew package (macdevtools)
  --manual    Remove manual-install files under PREFIX (tool + lib/shelltools)
  --all       Run both brew and manual uninstall steps (default)
  --untap     Also run: brew untap khakhasshi/tap
  --help      Show this help message
EOF
}

for arg in "$@"; do
	case "$arg" in
		--brew) MODE="brew" ;;
		--manual) MODE="manual" ;;
		--all) MODE="all" ;;
		--untap) UNTAP=true ;;
		--help|-h)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $arg"
			usage
			exit 1
			;;
	esac
done

uninstall_brew() {
	if command -v brew >/dev/null 2>&1; then
		if brew list --versions macdevtools >/dev/null 2>&1; then
			echo "Uninstalling Homebrew package: macdevtools"
			brew uninstall --formula macdevtools
		else
			echo "Homebrew package macdevtools is not installed."
		fi

		if [ "$UNTAP" = true ]; then
			if brew tap | grep -q '^khakhasshi/tap$'; then
				echo "Removing tap: khakhasshi/tap"
				brew untap khakhasshi/tap
			else
				echo "Tap khakhasshi/tap is not configured."
			fi
		fi
	else
		echo "Homebrew is not installed; skipping brew uninstall."
	fi
}

uninstall_manual() {
	echo "Removing manual-install files..."
	rm -f "$BINDIR/tool"
	rm -rf "$LIBDIR"
}

echo "Uninstall mode: $MODE"
case "$MODE" in
	brew)
		uninstall_brew
		;;
	manual)
		uninstall_manual
		;;
	all)
		uninstall_brew
		uninstall_manual
		;;
esac

echo "✓ Uninstall completed."

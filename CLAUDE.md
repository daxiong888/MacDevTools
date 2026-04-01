# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacDevTools is a macOS terminal toolkit providing system maintenance and development utilities through a unified `tool` command. It consists of standalone shell scripts organized under a single interactive TUI menu and CLI interface.

## Commands

### Installation
```bash
# Homebrew (recommended for users)
brew tap khakhasshi/tap
brew install macdevtools

# Makefile (for development)
make install      # Install to PREFIX/bin and PREFIX/lib/shelltools
make uninstall    # Remove installed files

# Manual script
./install.sh      # Auto-detects Apple Silicon vs Intel paths
```

### Running the toolkit
```bash
tool              # Interactive TUI menu
tool help         # Show CLI usage
tool <command>    # Direct command execution (e.g., tool brew, tool port 3000)
tool all          # One-click clean all caches
```

### Development verification
```bash
bash -n <script>.sh   # Syntax check without execution
```

## Architecture

### Entry point (`tool`)
- Resolves script directory dynamically (handles symlinks, Homebrew installs)
- Provides i18n support (en/zh/ja) via `t()` function with `~/.macdevtools_lang` config
- Two modes: interactive menu (no args) and CLI direct execution (with args)
- Script discovery via `find_scripts_dir()` - searches multiple paths for co-located scripts

### Modular scripts
Each tool is a standalone executable shell script:
- Cache cleanup: `clean_*_cache.sh` (brew, pip, node, xcode, docker, go, cargo, gem, steam, appletv, maven, gradle, logs)
- System tools: `check_network.sh`, `port_killer.sh`, `dns_lookup.sh`, `disk_usage.sh`, `pkg_outdated.sh`, `ssl_check.sh`, `traceroute_wrapper.sh`, `wifi_info.sh`, `sysinfo.sh`, `top_processes.sh`
- Utility: `fake_busy_build.sh`

### Platform support
- Primary: macOS (Darwin)
- Secondary: Linux (some scripts have platform-specific paths)
- Architecture detection: Apple Silicon (`arm64`) uses `/opt/homebrew`, Intel uses `/usr/local`

### Homebrew formula (`Formula/macdevtools.rb`)
- Installs all `.sh` files and `tool` to `libexec/`
- Symlinks `tool` to `bin/`
- Test: runs `tool help`

## Coding guidelines

From CONTRIBUTING.md:
- Prefer simple, readable shell scripts
- Keep cleanup commands predictable and safe
- Avoid destructive defaults when uncertainty exists
- Follow existing repository style
- Commit format: `feat:`, `fix:`, `docs:` prefixes

## Distribution

- Homebrew tap: `khakhasshi/tap`
- Version tracked in README badges and formula URL
- Scripts must remain co-located with `tool` for path resolution to work

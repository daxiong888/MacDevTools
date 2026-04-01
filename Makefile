PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/shelltools

SCRIPTS = clean_brew_cache.sh clean_pip_cache.sh clean_node_cache.sh \
		  clean_xcode_cache.sh clean_docker_cache.sh clean_go_cache.sh \
		  clean_cargo_cache.sh clean_gem_cache.sh clean_steam_cache.sh \
		  clean_appletv_cache.sh clean_maven_cache.sh clean_gradle_cache.sh \
		  check_network.sh port_killer.sh dns_lookup.sh fake_busy_build.sh \
		  clean_logs.sh disk_usage.sh pkg_outdated.sh ssl_check.sh \
		  traceroute_wrapper.sh wifi_info.sh sysinfo.sh top_processes.sh

.PHONY: install uninstall

install:
	@echo "Installing MacDevTools..."
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)
	@mkdir -p $(LIBDIR)/lib
	@cp $(SCRIPTS) $(LIBDIR)/
	@cp lib/common.sh $(LIBDIR)/lib/
	@sed 's|TOOL_DIR="$$HOME/ShellTools"|TOOL_DIR="$(LIBDIR)"|g' tool > $(BINDIR)/tool
	@chmod +x $(BINDIR)/tool
	@chmod +x $(LIBDIR)/*.sh
	@chmod +x $(LIBDIR)/lib/*.sh
	@echo "✓ Installed to $(BINDIR)/tool"

uninstall:
	@echo "Uninstalling MacDevTools..."
	@rm -f $(BINDIR)/tool
	@rm -rf $(LIBDIR)
	@echo "✓ Uninstalled"

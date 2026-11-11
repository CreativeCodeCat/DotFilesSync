CARGO   ?= cargo
BIN     ?= hyprsync
PREFIX  ?= /usr
DESTDIR ?=

BINDIR      = $(PREFIX)/bin
USERUNITDIR = $(PREFIX)/lib/systemd/user
UNIT        = hyprsync.service

.DEFAULT_GOAL := help
.PHONY: help build release install uninstall enable disable check pull push watch pull-dry push-dry clean

help: ## show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "} {printf "  %-12s %s\n", $$1, $$2}'

build: ## debug build
	$(CARGO) build

release: ## optimised build in target/release
	$(CARGO) build --release

# install copies prebuilt files only, so run `make release` first. That way
# `sudo make install` never runs cargo as root.
install: ## install $(BIN), the systemd unit, and enable it if run via sudo (run `make release` first)
	install -Dm755 target/release/$(BIN) $(DESTDIR)$(BINDIR)/$(BIN)
	sed 's|@BINDIR@|$(BINDIR)|' systemd/$(UNIT).in > target/$(UNIT)
	install -Dm644 target/$(UNIT) $(DESTDIR)$(USERUNITDIR)/$(UNIT)
	@if [ -n "$$SUDO_USER" ] && [ -z "$(DESTDIR)" ]; then \
		uid=$$(id -u "$$SUDO_USER"); \
		run="runuser -u $$SUDO_USER -- env XDG_RUNTIME_DIR=/run/user/$$uid systemctl --user"; \
		$$run daemon-reload && $$run enable --now $(UNIT) \
			&& echo "enabled $(UNIT) for $$SUDO_USER" \
			|| echo "could not enable $(UNIT) for $$SUDO_USER; run 'make enable' as your user"; \
	fi

uninstall: ## remove the binary and the systemd unit
	rm -f $(DESTDIR)$(BINDIR)/$(BIN) $(DESTDIR)$(USERUNITDIR)/$(UNIT)

enable: ## start watching now and at login (run as your user, not sudo)
	systemctl --user daemon-reload
	systemctl --user enable --now $(UNIT)

disable: ## stop the watch service and stop it starting at login
	systemctl --user disable --now $(UNIT)

check: ## run clippy with warnings as errors
	$(CARGO) clippy -- -D warnings

pull: ## copy ~/.config folders into this repo
	$(CARGO) run --quiet -- pull

push: ## copy this repo's folders into ~/.config
	$(CARGO) run --quiet -- push

watch: ## keep the repo in sync with ~/.config as it changes (Ctrl-C to stop)
	$(CARGO) run --quiet -- watch

pull-dry: ## show what pull would change
	$(CARGO) run --quiet -- pull --dry-run

push-dry: ## show what push would change
	$(CARGO) run --quiet -- push --dry-run

clean: ## remove build output
	$(CARGO) clean

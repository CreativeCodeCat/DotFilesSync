CARGO ?= cargo
BIN   ?= hyprsync

.DEFAULT_GOAL := help
.PHONY: help build release install check pull push pull-dry push-dry clean

help: ## show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "} {printf "  %-12s %s\n", $$1, $$2}'

build: ## debug build
	$(CARGO) build

release: ## optimised build in target/release
	$(CARGO) build --release

install: ## install hyprsync to ~/.cargo/bin
	$(CARGO) install --path . --force

check: ## run clippy with warnings as errors
	$(CARGO) clippy -- -D warnings

pull: ## copy ~/.config folders into this repo
	$(CARGO) run --quiet -- pull

push: ## copy this repo's folders into ~/.config
	$(CARGO) run --quiet -- push

pull-dry: ## show what pull would change
	$(CARGO) run --quiet -- pull --dry-run

push-dry: ## show what push would change
	$(CARGO) run --quiet -- push --dry-run

clean: ## remove build output
	$(CARGO) clean

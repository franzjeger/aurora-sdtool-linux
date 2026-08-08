# Aurora SD Tool — Linux packaging
#
# `make` on its own lists the available targets.

APP     := aurora-sdtool
APPID   := io.github.franzjeger.AuroraSDTool
VERSION := $(shell cat VERSION)
RELEASE ?= 1

PREFIX  ?= $(HOME)/.local
DESTDIR ?=

DISTDIR := dist
STAGING := $(DISTDIR)/staging

SHELL := /bin/bash

# Every shell source that lint covers. Keep in step with .github/workflows/ci.yml.
SHELL_SOURCES := src/$(APP) \
                 scripts/install.sh scripts/uninstall.sh scripts/vendor-upstream.sh \
                 scripts/lib/common.sh \
                 tests/run-tests.sh \
                 packaging/debian/build-deb.sh packaging/rpm/build-rpm.sh \
                 packaging/appimage/build-appimage.sh packaging/appimage/AppRun

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

.PHONY: install
install: ## Install for the current user (~/.local)
	@bash scripts/install.sh --prefix "$(PREFIX)" $(if $(DESTDIR),--destdir "$(DESTDIR)")

.PHONY: install-system
install-system: ## Install system-wide into /usr/local (needs root)
	@bash scripts/install.sh --system $(if $(DESTDIR),--destdir "$(DESTDIR)")

.PHONY: uninstall
uninstall: ## Remove the per-user install
	@bash scripts/uninstall.sh --prefix "$(PREFIX)"

.PHONY: uninstall-system
uninstall-system: ## Remove the system-wide install (needs root)
	@bash scripts/uninstall.sh --system

.PHONY: purge
purge: ## Remove the per-user install and delete settings and logs
	@bash scripts/uninstall.sh --prefix "$(PREFIX)" --purge

# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------

.PHONY: vendor
vendor: ## Refresh vendor/ from an upstream zip: make vendor ZIP=path/to.zip
	@test -n "$(ZIP)" || { echo "usage: make vendor ZIP=/path/to/Aurora_SDTool.zip" >&2; exit 1; }
	@bash scripts/vendor-upstream.sh "$(ZIP)"

.PHONY: verify
verify: ## Check the vendored payload against vendor/SHA256SUMS
	@cd vendor && sha256sum --check SHA256SUMS

.PHONY: check
check: lint test ## Run every check (lint + tests)

.PHONY: lint
lint: ## Lint shell scripts, the desktop entry and the AppStream metadata
	@fail=0; \
	if command -v shellcheck >/dev/null 2>&1; then \
		echo "==> shellcheck"; \
		shellcheck -x $(SHELL_SOURCES) || fail=1; \
	else echo "-- shellcheck not installed, skipping"; fi; \
	echo "==> bash -n"; \
	for f in $(SHELL_SOURCES); do bash -n "$$f" || fail=1; done; \
	if command -v desktop-file-validate >/dev/null 2>&1; then \
		echo "==> desktop-file-validate"; \
		desktop-file-validate share/applications/$(APP).desktop || fail=1; \
	else echo "-- desktop-file-validate not installed, skipping"; fi; \
	if command -v appstreamcli >/dev/null 2>&1; then \
		echo "==> appstreamcli validate"; \
		appstreamcli validate --no-net share/metainfo/$(APPID).metainfo.xml || fail=1; \
	else echo "-- appstreamcli not installed, skipping"; fi; \
	exit $$fail

.PHONY: test
test: ## Run the wrapper test suite
	@bash tests/run-tests.sh

# ---------------------------------------------------------------------------
# Packaging
# ---------------------------------------------------------------------------

.PHONY: dist
dist: ## Build a release tarball in dist/
	@mkdir -p $(DISTDIR)
	@git archive --format=tar.gz --prefix=$(APP)-$(VERSION)/ \
		-o $(DISTDIR)/$(APP)-$(VERSION).tar.gz HEAD
	@echo "==> $(DISTDIR)/$(APP)-$(VERSION).tar.gz"

.PHONY: deb
deb: ## Build a .deb package in dist/
	@bash packaging/debian/build-deb.sh

.PHONY: rpm
rpm: ## Build an .rpm package in dist/
	@bash packaging/rpm/build-rpm.sh

.PHONY: arch
arch: ## Build an Arch package with makepkg
	@cd packaging/arch && makepkg -f

.PHONY: appimage
appimage: ## Build an AppImage in dist/
	@bash packaging/appimage/build-appimage.sh

.PHONY: clean
clean: ## Remove build output
	@rm -rf $(DISTDIR)
	@rm -rf packaging/arch/{pkg,src,*.pkg.tar.zst}
	@echo "==> cleaned"

# ---------------------------------------------------------------------------

.PHONY: help
help: ## Show this help
	@echo "Aurora SD Tool $(VERSION) — Linux packaging"
	@echo
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
		{printf "  \033[1m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Variables: PREFIX=$(PREFIX) DESTDIR= RELEASE=$(RELEASE) ZIP="

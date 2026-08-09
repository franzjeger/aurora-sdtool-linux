#!/usr/bin/env bash
#
# Shared helpers for install.sh and uninstall.sh.
# Sourced, never executed directly.

# Repository root, derived from this file's location.
REPO_ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
readonly REPO_ROOT

APP=aurora-sdtool
readonly APP

# Reverse-DNS component ID used by AppStream and Flatpak. It belongs to the
# packager, not to CheatHappens — change it if you publish under another domain.
APPID=io.github.franzjeger.AuroraSDTool
# shellcheck disable=SC2034  # read by the scripts that source this file
readonly APPID

VERSION=$(<"$REPO_ROOT/VERSION")
# shellcheck disable=SC2034  # read by the scripts that source this file
readonly VERSION

if [[ -t 2 ]]; then
	C_RED=$'\033[31m' C_YELLOW=$'\033[33m' C_GREEN=$'\033[32m'
	C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_OFF=$'\033[0m'
else
	C_RED='' C_YELLOW='' C_GREEN='' C_BOLD='' C_DIM='' C_OFF=''
fi

log()  { printf '%s\n' "$*" >&2; }
info() { printf '%s==>%s %s\n' "$C_GREEN$C_BOLD" "$C_OFF" "$*" >&2; }
step() { printf '  %s->%s %s\n' "$C_DIM" "$C_OFF" "$*" >&2; }
warn() { printf '%swarning:%s %s\n' "$C_YELLOW$C_BOLD" "$C_OFF" "$*" >&2; }
err()  { printf '%serror:%s %s\n' "$C_RED$C_BOLD" "$C_OFF" "$*" >&2; }
die()  { err "$*"; exit 1; }

# The payload files that must be present for an install to be meaningful.
readonly PAYLOAD_FILES=(AuroraLauncher libSkiaSharp.so libHarfBuzzSharp.so)

check_payload() {
	local file
	for file in "${PAYLOAD_FILES[@]}"; do
		[[ -f $REPO_ROOT/vendor/$file ]] || die \
"vendor/$file is missing.

  This repository does not redistribute Aurora itself — see LEGAL.md. Supply
  your own copy of the official archive, which also provides the icon and
  upstream documentation:

    scripts/vendor-upstream.sh /path/to/Aurora_SDTool.zip"
	done
}

# Verify the payload against the recorded checksums, so a truncated download
# or a tampered file is caught before it lands in the install prefix.
verify_payload() {
	[[ -f $REPO_ROOT/vendor/SHA256SUMS ]] || {
		warn "vendor/SHA256SUMS is missing — skipping integrity check."
		return 0
	}
	if (cd "$REPO_ROOT/vendor" && sha256sum --quiet --check SHA256SUMS 2>/dev/null); then
		step "payload checksums verified"
	else
		die \
"The vendored payload does not match vendor/SHA256SUMS.

  Re-create it from a known-good upstream zip:
    scripts/vendor-upstream.sh /path/to/Aurora_SDTool.zip"
	fi
}

# Best-effort desktop database refresh. Missing tools are not an error: the
# entry still works, it just may not appear in the menu until the next login.
refresh_desktop_caches() {
	local datadir=$1
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database -q "$datadir/applications" 2>/dev/null || true
	fi
	if command -v gtk-update-icon-cache >/dev/null 2>&1; then
		gtk-update-icon-cache -qtf "$datadir/icons/hicolor" 2>/dev/null || true
	fi
}

# ~/.local/bin is on PATH by default on most modern distros, but not all.
check_path() {
	local bindir=$1
	case ":$PATH:" in
		*":$bindir:"*) return 0 ;;
	esac
	warn "$bindir is not on your PATH."
	log "  Add this to your shell profile to run '$APP' from a terminal:"
	log "    ${C_BOLD}export PATH=\"$bindir:\$PATH\"${C_OFF}"
	log "  The desktop menu entry works either way."
}

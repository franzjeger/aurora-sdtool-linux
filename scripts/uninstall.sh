#!/usr/bin/env bash
#
# Remove the Aurora Steam Deck Tool from an install prefix.
#
#   scripts/uninstall.sh                  remove the per-user install
#   sudo scripts/uninstall.sh --system    remove the system-wide install
#   scripts/uninstall.sh --purge          also delete settings, logs and cache
#
# This removes the *tool*. Aurora itself, and the Steam compatibility tool the
# tool registers, are removed from Aurora's own Tools tab before uninstalling.

set -euo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

PREFIX=
MODE=user
PURGE=0

usage() {
	cat <<EOF
Uninstall $APP.

Usage:
  scripts/uninstall.sh [options]

Options:
  --user            Remove from \$HOME/.local (default)
  --system          Remove from /usr/local (requires root)
  --prefix DIR      Remove from DIR
  --purge           Also delete per-user settings, logs and the runtime copy
  -h, --help        Show this message
EOF
}

while (( $# )); do
	case $1 in
		--user)     MODE=user ;;
		--system)   MODE=system ;;
		--prefix)   PREFIX=${2:?--prefix requires a directory}; MODE=custom; shift ;;
		--prefix=*) PREFIX=${1#*=}; MODE=custom ;;
		--purge)    PURGE=1 ;;
		-h|--help)  usage; exit 0 ;;
		*) die "Unknown option: $1 (try --help)" ;;
	esac
	shift
done

case $MODE in
	user)   PREFIX=${PREFIX:-$HOME/.local} ;;
	system) PREFIX=${PREFIX:-/usr/local} ;;
esac

if [[ $MODE == system && $EUID -ne 0 ]]; then
	die "--system removes files from $PREFIX and needs root. Re-run with sudo."
fi

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}

readonly TARGETS=(
	"$PREFIX/bin/$APP"
	"$PREFIX/lib/$APP"
	"$PREFIX/share/applications/$APP.desktop"
	"$PREFIX/share/icons/hicolor/256x256/apps/$APP.png"
	"$PREFIX/share/metainfo/$APPID.metainfo.xml"
	"$PREFIX/share/doc/$APP"
)

readonly USER_DATA=(
	"$XDG_CONFIG_HOME/$APP"
	"$XDG_DATA_HOME/$APP"
	"$XDG_STATE_HOME/$APP"
)

info "Removing $APP from $PREFIX"

# Undo the compatibility tool wrap first. It has to happen before the launcher
# is deleted, because the launcher is the only thing that knows how — otherwise
# a shim and a rewritten manifest are left behind in Steam's directory,
# outliving the package that put them there.
if [[ -x $PREFIX/bin/$APP ]]; then
	step "undoing the Steam compatibility tool wrap, if any"
	"$PREFIX/bin/$APP" --unwrap-compat-tool >/dev/null 2>&1 || true
fi

removed=0
for target in "${TARGETS[@]}"; do
	if [[ -e $target ]]; then
		step "removing $target"
		rm -rf -- "$target"
		removed=$(( removed + 1 ))
	fi
done

if (( removed == 0 )); then
	warn "Nothing to remove — no install found under $PREFIX."
else
	step "refreshing desktop caches"
	refresh_desktop_caches "$PREFIX/share"
fi

if (( PURGE )); then
	for target in "${USER_DATA[@]}"; do
		if [[ -e $target ]]; then
			step "purging $target"
			rm -rf -- "$target"
		fi
	done
	log ""
	info "Removed, including per-user settings."
else
	log ""
	info "Removed."
	if [[ -e $XDG_CONFIG_HOME/$APP || -e $XDG_DATA_HOME/$APP || -e $XDG_STATE_HOME/$APP ]]; then
		log ""
		log "  Your settings and logs were kept:"
		for target in "${USER_DATA[@]}"; do
			[[ -e $target ]] && log "    $target"
		done
		log ""
		log "  Delete them too with:"
		log "    ${C_BOLD}scripts/uninstall.sh --purge${C_OFF}"
	fi
fi

log ""
log "  Note: Aurora itself and its Steam compatibility tool are installed by"
log "  Aurora, not by this repository. Remove them from Aurora's Tools tab"
log "  before uninstalling, or delete the Aurora folder you chose at install"
log "  time and the 'AuroraLauncher' entry under Steam's compatibilitytools.d."
log ""

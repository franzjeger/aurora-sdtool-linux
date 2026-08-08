#!/usr/bin/env bash
#
# Install the Aurora Steam Deck Tool into an XDG-compliant prefix.
#
#   scripts/install.sh                 install for the current user (~/.local)
#   sudo scripts/install.sh --system   install for all users (/usr/local)
#   scripts/install.sh --prefix DIR    install into an arbitrary prefix
#
# DESTDIR is honoured so distro packaging can stage the tree.

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

PREFIX=
DESTDIR=${DESTDIR:-}
MODE=user
QUIET=0

usage() {
	cat <<EOF
Install $APP $VERSION.

Usage:
  scripts/install.sh [options]

Options:
  --user            Install into \$HOME/.local (default)
  --system          Install into /usr/local (requires root)
  --prefix DIR      Install into DIR
  --destdir DIR     Stage the install under DIR (for packaging)
  -q, --quiet       Only report warnings and errors
  -h, --help        Show this message
EOF
}

while (( $# )); do
	case $1 in
		--user)    MODE=user ;;
		--system)  MODE=system ;;
		--prefix)  PREFIX=${2:?--prefix requires a directory}; MODE=custom; shift ;;
		--prefix=*) PREFIX=${1#*=}; MODE=custom ;;
		--destdir) DESTDIR=${2:?--destdir requires a directory}; shift ;;
		--destdir=*) DESTDIR=${1#*=} ;;
		-q|--quiet) QUIET=1 ;;
		-h|--help) usage; exit 0 ;;
		*) die "Unknown option: $1 (try --help)" ;;
	esac
	shift
done

# Packaging scripts call this in the middle of their own output, where the
# per-file narration is noise — but warnings and errors must still get through.
if (( QUIET )); then
	log()  { :; }
	info() { :; }
	step() { :; }
fi

case $MODE in
	user)   PREFIX=${PREFIX:-$HOME/.local} ;;
	system) PREFIX=${PREFIX:-/usr/local} ;;
esac

if [[ $MODE == system && -z $DESTDIR && $EUID -ne 0 ]]; then
	die "--system installs into $PREFIX and needs root. Re-run with sudo."
fi

readonly BINDIR=$DESTDIR$PREFIX/bin
readonly LIBDIR=$DESTDIR$PREFIX/lib/$APP
readonly DATADIR=$DESTDIR$PREFIX/share
readonly DOCDIR=$DATADIR/doc/$APP

info "Installing $APP $VERSION into $PREFIX"
[[ -n $DESTDIR ]] && step "staging under DESTDIR=$DESTDIR"

check_payload
verify_payload

step "creating directories"
install -d "$BINDIR" "$LIBDIR" "$DOCDIR" \
	"$DATADIR/applications" \
	"$DATADIR/icons/hicolor/256x256/apps" \
	"$DATADIR/metainfo"

step "installing payload -> $PREFIX/lib/$APP"
install -m 755 "$REPO_ROOT/vendor/AuroraLauncher"      "$LIBDIR/AuroraLauncher"
install -m 644 "$REPO_ROOT/vendor/libSkiaSharp.so"     "$LIBDIR/libSkiaSharp.so"
install -m 644 "$REPO_ROOT/vendor/libHarfBuzzSharp.so" "$LIBDIR/libHarfBuzzSharp.so"
install -m 644 "$REPO_ROOT/vendor/SHA256SUMS"          "$LIBDIR/SHA256SUMS"

step "installing launcher -> $PREFIX/bin/$APP"
sed "s/@VERSION@/$VERSION/g" "$REPO_ROOT/src/$APP" >"$BINDIR/$APP"
chmod 755 "$BINDIR/$APP"

step "installing desktop entry, icon and metadata"
install -m 644 "$REPO_ROOT/share/applications/$APP.desktop" \
	"$DATADIR/applications/$APP.desktop"
install -m 644 "$REPO_ROOT/share/icons/hicolor/256x256/apps/$APP.png" \
	"$DATADIR/icons/hicolor/256x256/apps/$APP.png"
install -m 644 "$REPO_ROOT/share/metainfo/$APPID.metainfo.xml" \
	"$DATADIR/metainfo/$APPID.metainfo.xml"

step "installing documentation"
install -m 644 "$REPO_ROOT/README.md"                  "$DOCDIR/README.md"
install -m 644 "$REPO_ROOT/CHANGELOG.md"               "$DOCDIR/CHANGELOG.md"
install -m 644 "$REPO_ROOT/LEGAL.md"                   "$DOCDIR/LEGAL.md"
install -m 644 "$REPO_ROOT/docs/upstream/Readme.txt"   "$DOCDIR/upstream-Readme.txt"
install -m 644 "$REPO_ROOT/docs/upstream/Changelog.txt" "$DOCDIR/upstream-Changelog.txt"

if [[ -z $DESTDIR ]]; then
	step "refreshing desktop caches"
	refresh_desktop_caches "$PREFIX/share"
	[[ $MODE == user ]] && check_path "$PREFIX/bin"
fi

log ""
info "Installed."
log ""
log "  Launch it from your application menu, or run:"
log "    ${C_BOLD}$APP${C_OFF}"
log ""
log "  Check that this system has everything Aurora needs:"
log "    ${C_BOLD}$APP --doctor${C_OFF}"
log ""
log "  Uninstall with:"
log "    ${C_BOLD}scripts/uninstall.sh${C_OFF}$([[ $MODE == system ]] && echo ' --system')"
log ""

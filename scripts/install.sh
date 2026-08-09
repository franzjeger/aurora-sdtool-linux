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

# shellcheck source-path=SCRIPTDIR
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

# The compatibility tool shim lives beside the payload rather than in bin/:
# it is never run from PATH, only copied into Steam's tool directory by
# `aurora-sdtool --wrap-compat-tool`.
step "installing compatibility tool shim -> $PREFIX/lib/$APP"
install -m 755 "$REPO_ROOT/src/aurora-compat-launch" "$LIBDIR/aurora-compat-launch"

step "installing desktop entry and metadata"
install -m 644 "$REPO_ROOT/share/applications/$APP.desktop" \
	"$DATADIR/applications/$APP.desktop"
install -m 644 "$REPO_ROOT/share/metainfo/$APPID.metainfo.xml" \
	"$DATADIR/metainfo/$APPID.metainfo.xml"

# The icon is CheatHappens' artwork and is not redistributed here, so it only
# exists after scripts/vendor-upstream.sh has extracted it. Without it the
# desktop entry falls back to a generic icon, which is not worth failing over.
if [[ -f $REPO_ROOT/share/icons/hicolor/256x256/apps/$APP.png ]]; then
	step "installing icon"
	install -m 644 "$REPO_ROOT/share/icons/hicolor/256x256/apps/$APP.png" \
		"$DATADIR/icons/hicolor/256x256/apps/$APP.png"
else
	warn "No icon found — the menu entry will use a generic one."
	log "  Run 'scripts/vendor-upstream.sh <zip>' to extract it from the archive."
fi

step "installing documentation"
install -m 644 "$REPO_ROOT/README.md"    "$DOCDIR/README.md"
install -m 644 "$REPO_ROOT/CHANGELOG.md" "$DOCDIR/CHANGELOG.md"
install -m 644 "$REPO_ROOT/LEGAL.md"     "$DOCDIR/LEGAL.md"

# Same story: upstream's own README and changelog come out of the archive.
for doc in Readme Changelog; do
	if [[ -f $REPO_ROOT/docs/upstream/$doc.txt ]]; then
		install -m 644 "$REPO_ROOT/docs/upstream/$doc.txt" "$DOCDIR/upstream-$doc.txt"
	fi
done

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

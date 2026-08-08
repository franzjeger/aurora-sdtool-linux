#!/usr/bin/env bash
#
# Build a single-file AppImage that runs on any x86-64 distribution.
#
#   packaging/appimage/build-appimage.sh
#
# The AppImage bundles the payload and the packaging, and uses the host's
# graphics and font libraries — the same set any desktop already has. The
# wrapper checks for them at startup and names anything missing.

set -euo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../scripts/lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../scripts/lib/common.sh"

readonly HERE=$REPO_ROOT/packaging/appimage
readonly OUT=$REPO_ROOT/dist

find_appimagetool() {
	local candidate
	for candidate in appimagetool appimagetool-x86_64.AppImage; do
		command -v "$candidate" >/dev/null 2>&1 && { command -v "$candidate"; return 0; }
	done
	[[ -x $HERE/appimagetool-x86_64.AppImage ]] && { printf '%s\n' "$HERE/appimagetool-x86_64.AppImage"; return 0; }
	return 1
}

APPIMAGETOOL=$(find_appimagetool) || die \
"appimagetool was not found.

  Download it once into this directory:
    curl -L -o packaging/appimage/appimagetool-x86_64.AppImage \\
      https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x packaging/appimage/appimagetool-x86_64.AppImage

  Or install it from your distribution (Arch: appimagetool-bin from the AUR)."

info "Building $APP $VERSION AppImage"

check_payload
verify_payload

# appimagetool needs an AppDir whose modes it can trust, which a checkout on a
# network mount or a synced folder cannot provide.
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
APPDIR=$WORK/AppDir

step "staging AppDir"
bash "$REPO_ROOT/scripts/install.sh" --quiet --prefix /usr --destdir "$APPDIR"

# appimagetool expects the desktop entry, icon and AppRun at the AppDir root.
step "adding AppImage root files"
install -m 755 "$HERE/AppRun" "$APPDIR/AppRun"
install -m 644 "$REPO_ROOT/share/applications/$APP.desktop" "$APPDIR/$APP.desktop"
install -m 644 "$REPO_ROOT/share/icons/hicolor/256x256/apps/$APP.png" "$APPDIR/$APP.png"
install -Dm 644 "$REPO_ROOT/share/icons/hicolor/256x256/apps/$APP.png" \
	"$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP.png"
ln -sf "$APP.png" "$APPDIR/.DirIcon"

mkdir -p "$OUT"

step "running appimagetool"
IMAGE=$OUT/$APP-$VERSION-x86_64.AppImage
# ARCH is how appimagetool decides the target; it has no way to infer it from
# an AppDir that contains no ELF it recognises as the main binary.
ARCH=x86_64 "$APPIMAGETOOL" --no-appstream "$APPDIR" "$IMAGE"

log ""
info "Built $IMAGE"
log ""
log "  Run it with:"
log "    ${C_BOLD}chmod +x $IMAGE && $IMAGE${C_OFF}"
log ""
log "  Check the host has what it needs:"
log "    ${C_BOLD}$IMAGE --doctor${C_OFF}"
log ""

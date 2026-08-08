#!/usr/bin/env bash
#
# Build a .deb for Debian, Ubuntu, Mint and derivatives.
#
#   packaging/debian/build-deb.sh
#
# Needs only dpkg-deb, so it works on a non-Debian build host.

set -euo pipefail

# shellcheck source=../../scripts/lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../scripts/lib/common.sh"

RELEASE=${RELEASE:-1}
readonly ARCH=amd64
readonly DEB_VERSION=$VERSION-$RELEASE
readonly OUT=$REPO_ROOT/dist

command -v dpkg-deb >/dev/null 2>&1 || die "dpkg-deb is required but not installed."

info "Building $APP $DEB_VERSION ($ARCH) .deb"

check_payload
verify_payload

# Stage outside the repository. dpkg-deb needs exact file modes, and a checkout
# on a filesystem that cannot represent them — a network mount, an exFAT drive,
# a synced folder — would silently produce an unbuildable tree.
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
readonly STAGE=$WORK/$APP-$DEB_VERSION

install -d "$STAGE/DEBIAN"

step "staging the install tree"
bash "$REPO_ROOT/scripts/install.sh" --quiet --prefix /usr --destdir "$STAGE"

INSTALLED_SIZE=$(du -sk "$STAGE" | cut -f1)

step "writing DEBIAN/control"
cat >"$STAGE/DEBIAN/control" <<EOF
Package: $APP
Version: $DEB_VERSION
Section: games
Priority: optional
Architecture: $ARCH
Depends: libfontconfig1,
 libfreetype6,
 libexpat1,
 zlib1g,
 libbz2-1.0,
 libpng16-16 | libpng16-16t64,
 libbrotli1,
 libx11-6,
 libxcb1,
 libxau6,
 libxdmcp6,
 libstdc++6,
 libgcc-s1
Recommends: xwayland
Suggests: steam-installer
Installed-Size: $INSTALLED_SIZE
Maintainer: aurora-sdtool-linux packaging contributors <root@localhost>
Homepage: https://www.cheathappens.com/
Description: Aurora game trainer manager for Steam Play titles
 Aurora SD Tool installs the Aurora game trainer and registers it as a Steam
 Play compatibility tool, so a game launched from Steam starts with Aurora
 attached to it.
 .
 It detects Proton builds across every Steam library folder, including Flatpak
 and distribution-packaged runners, allows a Proton version to be selected per
 game or globally, and handles non-Steam launchers such as Ubisoft Connect and
 the Epic Games Store.
 .
 This package adds Linux desktop integration on top of the upstream Steam Deck
 build: an XDG-compliant layout, a launcher that works from a read-only prefix,
 startup diagnostics, and support for distributions other than SteamOS.
 .
 The application itself is proprietary software published by CheatHappens and
 is redistributed here unmodified. A CheatHappens account is required.
EOF

step "writing DEBIAN/postinst and DEBIAN/postrm"
cat >"$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
	command -v update-desktop-database >/dev/null 2>&1 &&
		update-desktop-database -q /usr/share/applications || true
	command -v gtk-update-icon-cache >/dev/null 2>&1 &&
		gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
fi
EOF

cat >"$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = remove ] || [ "$1" = purge ]; then
	command -v update-desktop-database >/dev/null 2>&1 &&
		update-desktop-database -q /usr/share/applications || true
	command -v gtk-update-icon-cache >/dev/null 2>&1 &&
		gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
fi
EOF

chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

# dpkg-deb refuses group- or world-writable files and demands 0555-0775 on
# maintainer scripts, so set every mode explicitly rather than inheriting.
step "normalising permissions"
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f -exec chmod 644 {} +
chmod 755 "$STAGE/usr/bin/$APP" \
	"$STAGE/usr/lib/$APP/AuroraLauncher" \
	"$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

step "building the package"
mkdir -p "$OUT"
DEB=$OUT/${APP}_${DEB_VERSION}_${ARCH}.deb
dpkg-deb --root-owner-group --build "$STAGE" "$DEB" >/dev/null

log ""
info "Built $DEB"
log ""
log "  Install it with:"
log "    ${C_BOLD}sudo apt install $DEB${C_OFF}"
log ""

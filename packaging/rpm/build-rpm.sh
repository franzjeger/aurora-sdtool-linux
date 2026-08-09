#!/usr/bin/env bash
#
# Build an .rpm for Fedora, RHEL, openSUSE and derivatives.
#
#   packaging/rpm/build-rpm.sh
#
# Builds in a private rpmbuild tree under dist/, leaving ~/rpmbuild alone.

set -euo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../scripts/lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../scripts/lib/common.sh"

readonly OUT=$REPO_ROOT/dist
readonly SPEC=$REPO_ROOT/packaging/rpm/$APP.spec

# rpmbuild needs a tree whose file modes it controls, which a checkout on a
# network mount or a synced folder cannot provide. Build outside the repository
# and copy only the finished package back.
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
readonly TOPDIR=$WORK/rpmbuild

command -v rpmbuild >/dev/null 2>&1 ||
	die "rpmbuild is required but not installed (Fedora: rpm-build, openSUSE: rpm-build, Arch: rpm-tools)."

info "Building $APP $VERSION .rpm"

check_payload
verify_payload

SPEC_VERSION=$(awk '/^Version:/ {print $2; exit}' "$SPEC")
[[ $SPEC_VERSION == "$VERSION" ]] ||
	warn "VERSION is $VERSION but the spec says $SPEC_VERSION — bump one of them."

step "preparing the build tree"
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} "$OUT"

step "creating the source tarball"
# git archive would drop an unstaged payload, so build the tarball from the
# working tree instead and exclude only what the package never needs.
tar --create --gzip \
	--file "$TOPDIR/SOURCES/$APP-$VERSION.tar.gz" \
	--directory "$(dirname "$REPO_ROOT")" \
	--transform "s,^$(basename "$REPO_ROOT"),$APP-$VERSION," \
	--exclude='.git' \
	--exclude='dist' \
	--exclude='packaging/arch/pkg' \
	--exclude='packaging/arch/src' \
	"$(basename "$REPO_ROOT")"

cp "$SPEC" "$TOPDIR/SPECS/"

# Remove any previous artefact first. Overwriting in place is not safe on a
# filesystem that does not truncate — a synced or network-mounted checkout
# leaves the tail of the older, larger file behind, and the result is a package
# that dpkg can still unpack but ar and apt reject as malformed.
rm -f "$OUT"/*/"$APP-$VERSION"-*.rpm "$OUT/$APP-$VERSION"-*.rpm

step "running rpmbuild"
rpmbuild -bb \
	--define "_topdir $TOPDIR" \
	--define "_rpmdir $OUT" \
	--define "_build_id_links none" \
	"$TOPDIR/SPECS/$APP.spec"

RPM=$(find "$OUT" -name "$APP-$VERSION-*.rpm" -print -quit)

log ""
info "Built $RPM"
log ""
log "  Install it with:"
log "    ${C_BOLD}sudo dnf install $RPM${C_OFF}   (Fedora/RHEL)"
log "    ${C_BOLD}sudo zypper install $RPM${C_OFF} (openSUSE)"
log ""

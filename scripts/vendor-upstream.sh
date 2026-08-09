#!/usr/bin/env bash
#
# Refresh vendor/ from an upstream Aurora_SDTool.zip.
#
#   scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
#
# Extracts the payload, records checksums, updates the upstream documentation
# copies and reports the version found in the changelog. Run this whenever
# CheatHappens publishes a new build.

set -euo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

ZIP=${1:-}
[[ -n $ZIP ]] || die "Usage: scripts/vendor-upstream.sh /path/to/Aurora_SDTool.zip"
[[ -f $ZIP ]] || die "No such file: $ZIP"

command -v unzip >/dev/null 2>&1 || die "unzip is required but not installed."

info "Vendoring upstream payload from $ZIP"

WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT

step "extracting"
unzip -q -o "$ZIP" -d "$WORK"

for file in "${PAYLOAD_FILES[@]}"; do
	[[ -f $WORK/$file ]] || die "The archive does not contain $file — is this an Aurora SD Tool zip?"
done

# Guard against an upstream build for another architecture slipping in.
if ! file -b "$WORK/AuroraLauncher" | grep -q 'ELF 64-bit.*x86-64'; then
	die "AuroraLauncher in this archive is not an x86-64 ELF binary."
fi

# -D throughout: none of these directories exist in a fresh clone, because
# everything they hold comes out of the archive rather than the repository.
step "updating vendor/"
install -Dm 755 "$WORK/AuroraLauncher"      "$REPO_ROOT/vendor/AuroraLauncher"
install -Dm 644 "$WORK/libSkiaSharp.so"     "$REPO_ROOT/vendor/libSkiaSharp.so"
install -Dm 644 "$WORK/libHarfBuzzSharp.so" "$REPO_ROOT/vendor/libHarfBuzzSharp.so"

if [[ -f $WORK/AuroraLauncher.png ]]; then
	step "updating icon"
	install -Dm 644 "$WORK/AuroraLauncher.png" \
		"$REPO_ROOT/share/icons/hicolor/256x256/apps/$APP.png"
fi

for doc in Readme.txt Changelog.txt; do
	if [[ -f $WORK/$doc ]]; then
		step "updating docs/upstream/$doc"
		install -Dm 644 "$WORK/$doc" "$REPO_ROOT/docs/upstream/$doc"
	fi
done

step "recording checksums"
(cd "$REPO_ROOT/vendor" && sha256sum "${PAYLOAD_FILES[@]}" >SHA256SUMS)

ZIP_SUM=$(sha256sum "$ZIP" | cut -d' ' -f1)

UPSTREAM_VERSION=$(
	grep -m1 -oE 'Changelog [0-9]+(\.[0-9]+)*' "$REPO_ROOT/docs/upstream/Changelog.txt" 2>/dev/null |
		grep -oE '[0-9]+(\.[0-9]+)*' || true
)
UPSTREAM_VERSION=${UPSTREAM_VERSION:-unknown}

# Built before the heredoc rather than inside it, so the backticks that make
# the Markdown table can carry a shellcheck directive of their own.
FILE_TABLE=$(
	printf '| File | SHA-256 |\n| --- | --- |\n'
	while read -r sum name; do
		# shellcheck disable=SC2016  # backticks are Markdown, not substitution
		printf '| `%s` | `%s` |\n' "$name" "$sum"
	done <"$REPO_ROOT/vendor/SHA256SUMS"
)

step "writing vendor/UPSTREAM.md"
cat >"$REPO_ROOT/vendor/UPSTREAM.md" <<EOF
# Vendored upstream payload

These files are redistributed verbatim from the official Aurora Steam Deck
Tool archive published by CheatHappens. They are **not** built from this
repository and are **not** covered by its licence — see [LEGAL.md](../LEGAL.md).

| Field | Value |
| --- | --- |
| Upstream version | \`$UPSTREAM_VERSION\` |
| Source archive | \`$(basename "$ZIP")\` |
| Archive SHA-256 | \`$ZIP_SUM\` |
| Architecture | \`x86-64\` |
| Runtime | .NET NativeAOT, Avalonia UI (X11 backend) |

## Files

$FILE_TABLE

## Refreshing

\`\`\`bash
scripts/vendor-upstream.sh /path/to/Aurora_SDTool.zip
\`\`\`

Then bump \`VERSION\` to match the upstream version and record the change in
[CHANGELOG.md](../CHANGELOG.md).
EOF

log ""
info "Vendored upstream version $UPSTREAM_VERSION"
log ""
log "  Next steps:"
log "    1. Update ${C_BOLD}VERSION${C_OFF} (currently $VERSION) if upstream changed"
log "    2. Record the change in ${C_BOLD}CHANGELOG.md${C_OFF}"
log "    3. Add a <release> entry to ${C_BOLD}share/metainfo/$APPID.metainfo.xml${C_OFF}"
log "    4. Run ${C_BOLD}make check${C_OFF}"
log ""

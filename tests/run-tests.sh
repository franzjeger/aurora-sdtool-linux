#!/usr/bin/env bash
#
# Wrapper test suite.
#
#   tests/run-tests.sh            run everything
#   tests/run-tests.sh payload    run tests whose name matches "payload"
#
# Every test runs against a temporary HOME and fixture payload, so nothing here
# touches a real install. The GUI is never launched: fixtures record that they
# were executed instead, which is what the launch-path tests assert against.

set -euo pipefail

REPO_ROOT=$(cd -P "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
readonly REPO_ROOT
readonly WRAPPER=$REPO_ROOT/src/aurora-sdtool
readonly FILTER=${1:-}

if [[ -t 1 ]]; then
	C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_DIM=$'\033[2m' C_BOLD=$'\033[1m' C_OFF=$'\033[0m'
else
	C_RED='' C_GREEN='' C_DIM='' C_BOLD='' C_OFF=''
fi

PASS=0 FAIL=0 SKIP=0
FAILED_TESTS=()

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

SANDBOX=
setup() {
	SANDBOX=$(mktemp -d)
	mkdir -p "$SANDBOX/home" "$SANDBOX/payload" "$SANDBOX/empty"

	# A fixture payload the wrapper accepts. AuroraLauncher is a script that
	# records its invocation, so a test can prove the GUI was never reached.
	cat >"$SANDBOX/payload/AuroraLauncher" <<EOF
#!/bin/sh
echo "launched \$*" > "$SANDBOX/launched"
EOF
	chmod +x "$SANDBOX/payload/AuroraLauncher"
	: >"$SANDBOX/payload/libSkiaSharp.so"
	: >"$SANDBOX/payload/libHarfBuzzSharp.so"
}

teardown() {
	[[ -n $SANDBOX && -d $SANDBOX ]] && rm -rf -- "$SANDBOX"
	SANDBOX=
}

# env -i, not plain env: the suite must not inherit the developer's DISPLAY,
# WAYLAND_DISPLAY or XDG_* variables, or the display tests pass locally and
# fail on a headless runner.
sandbox_env() {
	env -i \
		HOME="$SANDBOX/home" \
		XDG_CONFIG_HOME="$SANDBOX/home/.config" \
		XDG_DATA_HOME="$SANDBOX/home/.local/share" \
		XDG_STATE_HOME="$SANDBOX/home/.local/state" \
		PATH="/usr/bin:/bin" \
		"${WRAPPER_ENV[@]}" \
		"$@"
}

# Run the wrapper in that environment. Returns its exit status and leaves
# combined output in $OUTPUT.
OUTPUT=
run_wrapper() {
	local status=0
	OUTPUT=$(sandbox_env bash "$WRAPPER" "$@" 2>&1) || status=$?
	return "$status"
}

WRAPPER_ENV=()

# Source the wrapper in a subshell to unit-test its functions directly.
in_wrapper() {
	sandbox_env bash -c "source '$WRAPPER'; $1" 2>&1
}

ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_OFF" "$1"; PASS=$(( PASS + 1 )); }
no()   {
	printf '  %s✗%s %s\n' "$C_RED" "$C_OFF" "$1"
	[[ -n ${2:-} ]] && printf '    %s%s%s\n' "$C_DIM" "$2" "$C_OFF"
	FAIL=$(( FAIL + 1 ))
	FAILED_TESTS+=("$1")
}

assert_contains() {
	local haystack=$1 needle=$2 name=$3
	if [[ $haystack == *"$needle"* ]]; then
		ok "$name"
	else
		no "$name" "expected to find: $needle"
	fi
}

assert_not_contains() {
	local haystack=$1 needle=$2 name=$3
	if [[ $haystack != *"$needle"* ]]; then
		ok "$name"
	else
		no "$name" "did not expect to find: $needle"
	fi
}

# The fixture launcher writes $SANDBOX/launched when executed, so its absence
# proves the wrapper stopped before reaching the application.
assert_not_launched() {
	if [[ -e $SANDBOX/launched ]]; then
		no "$1" "the fixture launcher was executed"
	else
		ok "$1"
	fi
}

assert_eq() {
	local actual=$1 expected=$2 name=$3
	if [[ $actual == "$expected" ]]; then
		ok "$name"
	else
		no "$name" "expected '$expected', got '$actual'"
	fi
}

# Register a test. Skipped unless its name matches the filter.
test_case() {
	local name=$1
	if [[ -n $FILTER && $name != *"$FILTER"* ]]; then
		SKIP=$(( SKIP + 1 ))
		return 1
	fi
	printf '%s%s%s\n' "$C_BOLD" "$name" "$C_OFF"
	return 0
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_help_and_version() {
	test_case "informational commands" || return 0
	setup; WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")

	run_wrapper --help
	assert_contains "$OUTPUT" "--doctor" "--help lists --doctor"
	assert_contains "$OUTPUT" "AURORA_SDTOOL_LIBDIR" "--help documents the payload override"

	run_wrapper --version
	assert_contains "$OUTPUT" "aurora-sdtool wrapper" "--version identifies the wrapper"
	assert_contains "$OUTPUT" "$SANDBOX/payload" "--version reports the payload directory"

	# Neither may reach the application.
	assert_not_launched "informational commands do not launch the app"

	teardown
}

test_payload_discovery() {
	test_case "payload discovery" || return 0
	setup

	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")
	assert_eq "$(in_wrapper 'find_payload_dir /nonexistent')" "$SANDBOX/payload" \
		"AURORA_SDTOOL_LIBDIR wins over every other location"

	WRAPPER_ENV=()
	assert_eq "$(in_wrapper "is_payload_dir '$SANDBOX/payload' && echo yes || echo no")" yes \
		"a complete payload directory is accepted"
	assert_eq "$(in_wrapper "is_payload_dir '$SANDBOX/empty' && echo yes || echo no")" no \
		"an empty directory is rejected"

	# A partial copy must not be treated as usable.
	: >"$SANDBOX/empty/AuroraLauncher"
	assert_eq "$(in_wrapper "is_payload_dir '$SANDBOX/empty' && echo yes || echo no")" no \
		"a partial payload directory is rejected"

	# The bin/../lib layout the installer produces.
	mkdir -p "$SANDBOX/prefix/bin" "$SANDBOX/prefix/lib/aurora-sdtool"
	cp "$SANDBOX/payload"/* "$SANDBOX/prefix/lib/aurora-sdtool/"
	cp "$WRAPPER" "$SANDBOX/prefix/bin/aurora-sdtool"
	OUTPUT=$(sandbox_env bash "$SANDBOX/prefix/bin/aurora-sdtool" --where 2>&1)
	assert_contains "$OUTPUT" "$SANDBOX/prefix/lib/aurora-sdtool" \
		"an installed layout finds its payload through bin/../lib"

	# The same, reached through a symlink on PATH.
	mkdir -p "$SANDBOX/localbin"
	ln -sf "$SANDBOX/prefix/bin/aurora-sdtool" "$SANDBOX/localbin/aurora-sdtool"
	OUTPUT=$(sandbox_env bash "$SANDBOX/localbin/aurora-sdtool" --where 2>&1)
	assert_contains "$OUTPUT" "$SANDBOX/prefix/lib/aurora-sdtool" \
		"a symlinked entry point resolves to the real payload"

	teardown
}

test_missing_payload() {
	test_case "missing payload is reported" || return 0
	setup
	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/empty")

	local status=0
	run_wrapper || status=$?
	assert_eq "$status" 1 "an invalid AURORA_SDTOOL_LIBDIR exits 1"
	assert_contains "$OUTPUT" "does not contain the Aurora payload" \
		"the error names the cause"

	teardown
}

test_no_display() {
	test_case "display detection" || return 0
	setup
	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")

	local status=0
	run_wrapper || status=$?
	assert_eq "$status" 1 "no DISPLAY and no WAYLAND_DISPLAY exits 1"
	assert_not_launched "the application is not launched without a display"

	# Either failure is correct here: a build host may genuinely lack one of
	# the required libraries, which is checked before the display.
	if [[ $OUTPUT == *"No graphical display found"* || $OUTPUT == *"required system libraries are missing"* ]]; then
		ok "the failure is explained"
	else
		no "the failure is explained" "unexpected output: $OUTPUT"
	fi

	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload" WAYLAND_DISPLAY=wayland-0)
	status=0
	run_wrapper || status=$?
	if [[ $OUTPUT == *"XWayland"* || $OUTPUT == *"required system libraries are missing"* ]]; then
		ok "a Wayland session without XWayland is explained"
	else
		no "a Wayland session without XWayland is explained" "unexpected output: $OUTPUT"
	fi

	teardown
}

test_xdg_paths() {
	test_case "XDG base directories" || return 0
	setup
	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")

	run_wrapper --log
	assert_eq "$OUTPUT" "$SANDBOX/home/.local/state/aurora-sdtool/aurora-sdtool.log" \
		"the log path honours XDG_STATE_HOME"

	run_wrapper --where
	assert_contains "$OUTPUT" "$SANDBOX/home/.config/aurora-sdtool" \
		"the config path honours XDG_CONFIG_HOME"
	assert_contains "$OUTPUT" "$SANDBOX/home/.local/share/aurora-sdtool/app" \
		"the runtime path honours XDG_DATA_HOME"

	teardown
}

test_config_file() {
	test_case "configuration file" || return 0
	setup

	mkdir -p "$SANDBOX/home/.config/aurora-sdtool"
	printf 'export AURORA_SDTOOL_LIBDIR=%q\n' "$SANDBOX/payload" \
		>"$SANDBOX/home/.config/aurora-sdtool/env"

	WRAPPER_ENV=()
	run_wrapper --where
	assert_contains "$OUTPUT" "payload:  $SANDBOX/payload" \
		"the config env file is sourced at startup"

	teardown
}

test_doctor() {
	test_case "doctor" || return 0
	setup
	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")

	# --doctor reports problems through its exit status, so a non-zero result
	# is expected on a headless runner; it must never crash.
	run_wrapper --doctor || true
	local section
	for section in System Payload Libraries Display Steam; do
		assert_contains "$OUTPUT" "$section" "--doctor reports the $section section"
	done
	assert_contains "$OUTPUT" "$SANDBOX/payload" "--doctor locates the payload"
	assert_not_contains "$OUTPUT" "line " "--doctor produces no shell errors"

	assert_not_launched "--doctor does not launch the app"

	teardown
}

test_install_uninstall() {
	test_case "install and uninstall round trip" || return 0
	setup

	if [[ ! -f $REPO_ROOT/vendor/AuroraLauncher ]]; then
		printf '  %s- skipped: vendor/ has no payload%s\n' "$C_DIM" "$C_OFF"
		SKIP=$(( SKIP + 1 ))
		teardown
		return 0
	fi

	local prefix=$SANDBOX/prefix
	WRAPPER_ENV=()
	sandbox_env bash "$REPO_ROOT/scripts/install.sh" --prefix "$prefix" >/dev/null 2>&1

	local f
	for f in \
		bin/aurora-sdtool \
		lib/aurora-sdtool/AuroraLauncher \
		lib/aurora-sdtool/libSkiaSharp.so \
		lib/aurora-sdtool/libHarfBuzzSharp.so \
		lib/aurora-sdtool/aurora-compat-launch \
		share/applications/aurora-sdtool.desktop \
		share/icons/hicolor/256x256/apps/aurora-sdtool.png \
		share/metainfo/io.github.franzjeger.AuroraSDTool.metainfo.xml \
		share/doc/aurora-sdtool/README.md
	do
		if [[ -f $prefix/$f ]]; then ok "installs $f"; else no "installs $f"; fi
	done

	if [[ -x $prefix/bin/aurora-sdtool ]]; then
		ok "the installed launcher is executable"
	else
		no "the installed launcher is executable"
	fi

	# @VERSION@ must have been substituted during install.
	OUTPUT=$(sandbox_env bash "$prefix/bin/aurora-sdtool" --version 2>&1)
	assert_contains "$OUTPUT" "$(cat "$REPO_ROOT/VERSION")" \
		"the installed launcher reports the real version"
	assert_not_contains "$OUTPUT" "@VERSION@" "the version placeholder is substituted"

	sandbox_env bash "$REPO_ROOT/scripts/uninstall.sh" --prefix "$prefix" >/dev/null 2>&1

	local leftovers
	leftovers=$(find "$prefix" -name '*aurora*' -o -name '*AuroraLauncher*' 2>/dev/null || true)
	assert_eq "$leftovers" "" "uninstall removes every installed file"

	teardown
}

test_steam_detection() {
	test_case "Steam detection" || return 0
	setup
	WRAPPER_ENV=()

	# /usr/share/steam belongs to a distro-packaged Steam and is reported when
	# it exists, so only the per-user locations can be asserted absent here.
	assert_not_contains "$(in_wrapper 'steam_roots')" "$SANDBOX/home" \
		"an empty home reports no per-user Steam directories"

	mkdir -p "$SANDBOX/home/.steam/steam/compatibilitytools.d"
	assert_contains "$(in_wrapper 'steam_roots')" "$SANDBOX/home/.steam/steam" \
		"a native Steam install is found"
	assert_contains "$(in_wrapper 'compat_tool_dirs')" "compatibilitytools.d" \
		"the compatibility tool directory is found"

	mkdir -p "$SANDBOX/home/.var/app/com.valvesoftware.Steam/data/Steam"
	assert_contains "$(in_wrapper 'steam_roots')" "com.valvesoftware.Steam" \
		"a Flatpak Steam install is found"

	teardown
}

test_install_hints() {
	test_case "dependency install hints" || return 0
	setup
	WRAPPER_ENV=()

	local hint
	hint=$(in_wrapper 'install_hint')
	if [[ -n $hint ]]; then
		ok "an install hint is produced for this distribution"
	else
		no "an install hint is produced for this distribution"
	fi

	# Whatever the distribution, the hint must be a command or an instruction,
	# never an empty string or a shell error.
	assert_not_contains "$hint" "line " "the install hint is not a shell error"

	teardown
}

# ---------------------------------------------------------------------------
# Steam compatibility tool
# ---------------------------------------------------------------------------

# A stand-in for the tool directory Aurora registers with Steam, matching the
# layout and manifest format upstream produces.
make_compat_tool() {
	local tool=$SANDBOX/home/.local/share/Steam/compatibilitytools.d/AuroraLauncher
	mkdir -p "$tool"

	# Records its argv one per line, so pass-through can be asserted exactly,
	# and exits 42 so the exit status can be traced through the shim.
	cat >"$tool/AuroraLauncher" <<EOF
#!/bin/sh
: > "$SANDBOX/argv"
for a in "\$@"; do printf '[%s]\n' "\$a" >> "$SANDBOX/argv"; done
printf 'CWD=%s\n' "\$(pwd)" >> "$SANDBOX/argv"
printf 'LDLP=%s\n' "\$LD_LIBRARY_PATH" >> "$SANDBOX/argv"
exit 42
EOF
	chmod +x "$tool/AuroraLauncher"
	: >"$tool/libSkiaSharp.so"
	: >"$tool/libHarfBuzzSharp.so"

	# Upstream's real format, as shipped by 3.2.0: two entries, and Steam
	# selects between them by verb. Games take the waitforexitandrun path.
	cat >"$tool/toolmanifest.vdf" <<'EOF'
"manifest"
{
  "commandline" "/AuroraLauncher run"
  "commandline_waitforexitandrun" "/AuroraLauncher waitforexitandrun"
}
EOF
	printf '%s\n' "$tool"
}

# Mirrors compat_tool_is_wrapped: the shim exists and every command line goes
# through it. A partial rewrite is not a wrap.
compat_wrapped() {
	[[ -f $1/aurora-compat-launch ]] || return 1
	grep -q '"/AuroraLauncher' "$1/toolmanifest.vdf" && return 1
	grep -q '"/aurora-compat-launch' "$1/toolmanifest.vdf"
}

test_compat_shim() {
	test_case "compatibility tool shim" || return 0
	setup

	local tool status=0
	tool=$(make_compat_tool)
	install -m 755 "$REPO_ROOT/src/aurora-compat-launch" "$tool/aurora-compat-launch"

	# Exactly how Steam invokes it, including an argument containing a space.
	( cd / && sandbox_env "$tool/aurora-compat-launch" \
		waitforexitandrun "/games/My Game/game.exe" -novid ) || status=$?

	assert_eq "$status" 42 "the launcher's exit status is propagated"

	local argv
	argv=$(<"$SANDBOX/argv")
	assert_contains "$argv" "[waitforexitandrun]" "the Steam verb is passed through"
	assert_contains "$argv" "[/games/My Game/game.exe]" \
		"an argument containing a space stays one argument"
	assert_contains "$argv" "[-novid]" "trailing game arguments are passed through"
	assert_contains "$argv" "CWD=/" "the working directory Steam set is not changed"
	assert_contains "$argv" "LDLP=$tool" "LD_LIBRARY_PATH points at the tool directory"

	local log=$SANDBOX/home/.local/state/aurora-sdtool/compat-tool.log
	if [[ -f $log ]]; then
		ok "the shim writes a compat-tool log"
		assert_contains "$(<"$log")" "exec AuroraLauncher" "the log records the hand-off"
	else
		no "the shim writes a compat-tool log"
	fi

	# With no launcher to hand off to, it must fail loudly rather than silently.
	rm -f "$tool/AuroraLauncher"
	status=0
	OUTPUT=$(sandbox_env "$tool/aurora-compat-launch" waitforexitandrun 2>&1) || status=$?
	assert_eq "$status" 127 "a missing launcher exits 127"
	assert_contains "$OUTPUT" "missing or not executable" "and says why"

	teardown
}

test_compat_wrap() {
	test_case "compatibility tool wrapping" || return 0
	setup
	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")

	local tool
	tool=$(make_compat_tool)
	cp "$REPO_ROOT/src/aurora-compat-launch" "$SANDBOX/payload/aurora-compat-launch"
	cp "$tool/toolmanifest.vdf" "$SANDBOX/manifest.orig"

	run_wrapper --wrap-compat-tool
	local wrapped
	wrapped=$(<"$tool/toolmanifest.vdf")
	assert_contains "$wrapped" '"/aurora-compat-launch run"' \
		"wrapping repoints the run entry at the shim"
	# The entry games actually take. Wrapping only the first would leave the
	# case that matters going straight to the launcher.
	assert_contains "$wrapped" '"/aurora-compat-launch waitforexitandrun"' \
		"wrapping repoints the waitforexitandrun entry at the shim"
	assert_not_contains "$wrapped" '"/AuroraLauncher' \
		"no command line still points at the launcher directly"
	if [[ -x $tool/aurora-compat-launch ]]; then
		ok "wrapping installs the shim executable"
	else
		no "wrapping installs the shim executable"
	fi
	if [[ -f $tool/toolmanifest.vdf.aurora-sdtool.bak ]]; then
		ok "wrapping backs up the original manifest"
	else
		no "wrapping backs up the original manifest"
	fi
	assert_contains "$(<"$tool/aurora-sdtool-wrap.conf")" "TARGET=AuroraLauncher" \
		"wrapping records the original target"

	run_wrapper --doctor || true
	assert_contains "$OUTPUT" "compatibility tool is wrapped" "--doctor reports the wrap"

	# Wrapping twice must not stack shims or lose the original command line.
	run_wrapper --wrap-compat-tool
	assert_contains "$OUTPUT" "already wrapped" "wrapping twice is a no-op"
	assert_contains "$(<"$tool/aurora-sdtool-wrap.conf")" "TARGET=AuroraLauncher" \
		"the recorded target survives a second wrap"

	# An Aurora self-update rewrites the manifest and orphans the shim.
	cp "$SANDBOX/manifest.orig" "$tool/toolmanifest.vdf"
	run_wrapper --doctor || true
	assert_contains "$OUTPUT" "wrap was undone" "--doctor detects a wrap lost to an update"

	run_wrapper --wrap-compat-tool
	run_wrapper --unwrap-compat-tool
	if diff -q "$SANDBOX/manifest.orig" "$tool/toolmanifest.vdf" >/dev/null; then
		ok "unwrapping restores the manifest byte for byte"
	else
		no "unwrapping restores the manifest byte for byte"
	fi
	if [[ -e $tool/aurora-compat-launch || -e $tool/aurora-sdtool-wrap.conf ]]; then
		no "unwrapping leaves nothing behind"
	else
		ok "unwrapping leaves nothing behind"
	fi

	# Opening the desktop app re-runs upstream's setup, which rewrites the
	# manifest. The next start has to notice and put the wrap back by itself.
	run_wrapper --wrap-compat-tool
	cp "$SANDBOX/manifest.orig" "$tool/toolmanifest.vdf"
	assert_eq "$(in_wrapper 'restore_wrap_if_dropped >/dev/null 2>&1; echo done')" "done" \
		"restoring a dropped wrap completes"
	if compat_wrapped "$tool"; then
		ok "a wrap dropped by upstream's setup is restored automatically"
	else
		no "a wrap dropped by upstream's setup is restored automatically"
	fi

	# With no shim present there is nothing of ours to restore, so it must
	# leave an unwrapped tool alone rather than wrapping it uninvited.
	run_wrapper --unwrap-compat-tool
	in_wrapper 'restore_wrap_if_dropped >/dev/null 2>&1' >/dev/null
	if compat_wrapped "$tool"; then
		no "an unwrapped tool is left alone"
	else
		ok "an unwrapped tool is left alone"
	fi

	# A manifest in an unfamiliar format must be refused, not mangled.
	printf '"manifest"\n{\n  "version" "2"\n}\n' >"$tool/toolmanifest.vdf"
	cp "$tool/toolmanifest.vdf" "$SANDBOX/manifest.weird"
	local status=0
	run_wrapper --wrap-compat-tool || status=$?
	assert_eq "$status" 1 "an unrecognised manifest is refused"
	if diff -q "$SANDBOX/manifest.weird" "$tool/toolmanifest.vdf" >/dev/null; then
		ok "a refused manifest is left untouched"
	else
		no "a refused manifest is left untouched"
	fi

	teardown
}

test_runtime_mirror() {
	test_case "runtime mirroring" || return 0
	setup
	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")

	local rundir=$SANDBOX/home/.local/share/aurora-sdtool/app

	assert_eq "$(in_wrapper "sync_runtime_dir '$SANDBOX/payload' >/dev/null 2>&1; echo done")" "done" \
		"mirroring completes"
	if [[ -x $rundir/AuroraLauncher && -f $rundir/libSkiaSharp.so && -f $rundir/libHarfBuzzSharp.so ]]; then
		ok "the payload is mirrored into the runtime directory"
	else
		no "the payload is mirrored into the runtime directory"
	fi

	# Upstream's installer deletes the launcher it ran from, so the next start
	# has to put it back rather than fail.
	rm -f "$rundir/AuroraLauncher" "$rundir/libSkiaSharp.so"
	in_wrapper "sync_runtime_dir '$SANDBOX/payload' >/dev/null" >/dev/null
	if [[ -x $rundir/AuroraLauncher && -f $rundir/libSkiaSharp.so ]]; then
		ok "a payload deleted by Aurora is restored on the next launch"
	else
		no "a payload deleted by Aurora is restored on the next launch"
	fi

	teardown
}

test_uninstall_unwraps() {
	test_case "uninstall undoes the compatibility tool wrap" || return 0
	setup

	if [[ ! -f $REPO_ROOT/vendor/AuroraLauncher ]]; then
		printf '  %s- skipped: vendor/ has no payload%s\n' "$C_DIM" "$C_OFF"
		SKIP=$(( SKIP + 1 )); teardown; return 0
	fi

	local tool prefix=$SANDBOX/prefix
	tool=$(make_compat_tool)
	cp "$tool/toolmanifest.vdf" "$SANDBOX/manifest.orig"

	WRAPPER_ENV=()
	sandbox_env bash "$REPO_ROOT/scripts/install.sh" --quiet --prefix "$prefix" >/dev/null 2>&1
	sandbox_env bash "$prefix/bin/aurora-sdtool" --wrap-compat-tool >/dev/null 2>&1

	if compat_wrapped "$tool"; then
		ok "the tool is wrapped before uninstalling"
	else
		no "the tool is wrapped before uninstalling"
	fi

	# Removing the package must not orphan a shim inside Steam's directory.
	sandbox_env bash "$REPO_ROOT/scripts/uninstall.sh" --prefix "$prefix" >/dev/null 2>&1

	if [[ -e $tool/aurora-compat-launch || -e $tool/aurora-sdtool-wrap.conf ]]; then
		no "uninstalling removes the shim from Steam's directory"
	else
		ok "uninstalling removes the shim from Steam's directory"
	fi
	if diff -q "$SANDBOX/manifest.orig" "$tool/toolmanifest.vdf" >/dev/null; then
		ok "uninstalling restores the original tool manifest"
	else
		no "uninstalling restores the original tool manifest"
	fi

	teardown
}

test_doctor_integrity() {
	test_case "doctor verifies payload integrity" || return 0
	setup
	WRAPPER_ENV=(AURORA_SDTOOL_LIBDIR="$SANDBOX/payload")

	(cd "$SANDBOX/payload" && sha256sum AuroraLauncher libSkiaSharp.so libHarfBuzzSharp.so >SHA256SUMS)
	run_wrapper --doctor || true
	assert_contains "$OUTPUT" "payload matches SHA256SUMS" "a matching payload is reported as intact"

	printf 'tampered' >>"$SANDBOX/payload/libSkiaSharp.so"
	local status=0
	run_wrapper --doctor || status=$?
	assert_contains "$OUTPUT" "does not match SHA256SUMS" "a modified payload is reported"
	assert_eq "$status" 1 "a modified payload makes --doctor exit non-zero"

	rm -f "$SANDBOX/payload/SHA256SUMS"
	run_wrapper --doctor || true
	assert_contains "$OUTPUT" "integrity not checked" "a missing SHA256SUMS is called out, not ignored"

	teardown
}

test_required_libs_in_sync() {
	test_case "library lists stay in sync" || return 0
	setup

	# The shim carries its own copy because it runs from Steam's directory,
	# where nothing else from this project exists. Drift would mean the two
	# entry points disagree about what Aurora needs.
	local from_launcher from_shim
	from_launcher=$(sed -n "/^readonly DLOPEN_LIBS=(/,/^)/p" "$REPO_ROOT/src/aurora-sdtool" |
		grep -oE 'lib[A-Za-z0-9_.+-]*\.so[0-9.]*' | sort)
	from_shim=$(sed -n '/^DLOPEN_LIBS=(/,/^)/p' "$REPO_ROOT/src/aurora-compat-launch" |
		grep -oE 'lib[A-Za-z0-9_.+-]*\.so[0-9.]*' | sort)

	if [[ -n $from_launcher && $from_launcher == "$from_shim" ]]; then
		ok "aurora-sdtool and aurora-compat-launch require the same libraries"
	else
		no "aurora-sdtool and aurora-compat-launch require the same libraries" \
			"differences: $(comm -3 <(printf '%s' "$from_launcher") <(printf '%s' "$from_shim") | tr -d '\t' | tr '\n' ' ')"
	fi

	teardown
}

# ---------------------------------------------------------------------------

main() {
	printf '%saurora-sdtool test suite%s\n' "$C_BOLD" "$C_OFF"
	[[ -n $FILTER ]] && printf '%sfilter: %s%s\n' "$C_DIM" "$FILTER" "$C_OFF"
	printf '\n'

	trap teardown EXIT

	test_help_and_version
	test_payload_discovery
	test_missing_payload
	test_no_display
	test_xdg_paths
	test_config_file
	test_doctor
	test_steam_detection
	test_install_hints
	test_compat_shim
	test_compat_wrap
	test_runtime_mirror
	test_doctor_integrity
	test_uninstall_unwraps
	test_required_libs_in_sync
	test_install_uninstall

	printf '\n'
	if (( FAIL == 0 )); then
		printf '%s%d passed%s' "$C_GREEN$C_BOLD" "$PASS" "$C_OFF"
		(( SKIP )) && printf ', %d skipped' "$SKIP"
		printf '\n'
		return 0
	fi

	printf '%s%d failed%s, %d passed' "$C_RED$C_BOLD" "$FAIL" "$C_OFF" "$PASS"
	(( SKIP )) && printf ', %d skipped' "$SKIP"
	printf '\n'
	local name
	for name in "${FAILED_TESTS[@]}"; do
		printf '  %s✗%s %s\n' "$C_RED" "$C_OFF" "$name"
	done
	return 1
}

main "$@"

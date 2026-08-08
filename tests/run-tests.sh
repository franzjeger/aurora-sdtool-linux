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
	C_RED= C_GREEN= C_DIM= C_BOLD= C_OFF=
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
		"~/.config/aurora-sdtool/env is sourced at startup"

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

# Contributing

## Scope

This repository packages a closed-source application. That draws a hard line
through the middle of any bug report:

- **Aurora itself misbehaves** — the UI, login, Proton selection, trainers,
  game hooking. Report it to CheatHappens. Nothing here can fix it.
- **Getting Aurora onto the system misbehaves** — installing, launching,
  desktop integration, packaging, missing dependencies, distro quirks. That is
  this repository's job.

`aurora-sdtool --doctor` output belongs in every report of the second kind.

Patching the upstream binary is out of scope. If a problem cannot be solved
from outside the process, it belongs upstream.

## Working on it

```bash
git clone <this repo> && cd aurora-sdtool-linux
src/aurora-sdtool --doctor      # runs straight from the checkout
make check                      # lint + tests
```

`make check` needs `shellcheck`, `desktop-file-utils` and `appstream` for the
full set; each check is skipped with a note when its tool is missing, so a
partial toolchain still works locally. CI runs all of them.

## Shell style

Everything is Bash targeting 4.4 or newer — SteamOS and Debian oldstable both
clear that bar.

- `set -euo pipefail` at the top of every script.
- Tabs for indentation, matching the existing files.
- Quote expansions. `shellcheck` runs in CI and its findings are not advisory.
- `readonly` for constants; keep functions single-purpose.
- Error messages name the file or library at fault and give the command that
  fixes it. A message the user cannot act on is a bug.

## Tests

`tests/run-tests.sh` covers the wrapper's own logic — payload discovery,
argument handling, XDG paths, failure modes. It never launches the GUI, so it
runs headless in CI.

Add a case for any behaviour you change. Tests run against `src/aurora-sdtool`
directly, with `AURORA_SDTOOL_LIBDIR` and a temporary `HOME` pointing at
fixtures, so no test touches a real install.

## Updating the payload

```bash
scripts/vendor-upstream.sh /path/to/Aurora_SDTool.zip
```

Then bump `VERSION`, add a `CHANGELOG.md` entry and a `<release>` element to
`share/metainfo/io.github.franzjeger.AuroraSDTool.metainfo.xml`, and run `make check`.

Never edit anything in `vendor/` by hand — the checksums in `vendor/SHA256SUMS`
are what proves the payload is upstream's, unmodified.

## Adding a distribution

Two places need to know about it:

1. `install_hint()` in `src/aurora-sdtool` — the package names for that
   distro's `ID` and `ID_LIKE`.
2. `docs/DISTROS.md` — anything surprising about it.

If it needs its own package format, add a directory under `packaging/` with a
`build-*.sh` that writes into `dist/`, and a target in the `Makefile`.

## Commits

Conventional Commits, scoped to the area touched:

```
fix(wrapper): resolve payload through symlinked bin entries
feat(packaging): add openSUSE package names to the install hint
docs(distros): note NixOS needs steam-run
```

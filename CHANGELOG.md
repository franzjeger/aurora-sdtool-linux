# Changelog

Changes to the Linux packaging. Upstream application changes are recorded
separately in upstream's own `Changelog.txt`, which
`scripts/vendor-upstream.sh` extracts into `docs/upstream/`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions track the upstream release they package.

## [3.2.0] — 2026-08-09

First packaged release, built on upstream 3.2.0.

### Added

- `aurora-sdtool` launcher wrapper, which resolves the payload through
  symlinks, sets up the library search path and execs the upstream binary.
- Startup preflight for the libraries the payload needs. The dynamic linker is
  asked what it cannot resolve, rather than matching a fixed list of sonames
  that differ between distributions; a short static list covers only what the
  linker cannot see, being the X11 stack Avalonia opens with dlopen.
  A missing library is reported by name with the install command for the
  detected distribution, instead of the .NET `DllNotFoundException` and core
  dump upstream produces.
- Display-server detection. A Wayland session without XWayland, or no display
  at all, is explained rather than crashing in `XOpenDisplay`.
- Automatic fallback to `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` when the
  system has no ICU library, which otherwise aborts .NET at startup.
- Per-user runtime directory. Aurora stores its settings next to its own
  executable, and its installer deletes the launcher it was started from. The
  wrapper therefore treats the install prefix as pristine source and always
  runs from a mirror in `~/.local/share/aurora-sdtool/app`, restoring anything
  removed from underneath it on the next start.
- `--doctor`, which checks architecture, payload integrity, libraries, display
  server, Steam locations and desktop integration, and suggests a fix for each
  problem found.
- `--where`, `--log`, `--version` and `--help`.
- XDG base directory layout for configuration, runtime data and logs.
- Optional `~/.config/aurora-sdtool/env`, sourced at startup, for pinning
  environment overrides.
- `scripts/install.sh` and `scripts/uninstall.sh`, supporting per-user,
  system-wide and arbitrary prefixes, `DESTDIR` staging, and `--purge`.
- `scripts/vendor-upstream.sh`, which refreshes the payload from an official
  zip, validates the architecture, records checksums and regenerates
  `vendor/UPSTREAM.md`.
- Desktop entry and AppStream metadata. The icon comes from the archive.
- Packaging for Arch (`PKGBUILD`), Debian (`.deb`), RPM (`.spec`), AppImage and
  Flatpak.
- Wrapper test suite and a `make check` target running shellcheck, `bash -n`,
  `desktop-file-validate` and `appstreamcli validate`.
- GitHub Actions workflow running the checks and building packages.
- Documentation: installation, per-distribution notes, troubleshooting, the
  redistribution and trademark position in `LEGAL.md`, and `docs/NATIVE-TOOLS.md`
  on where native Linux scanners fit alongside Aurora.
- Steam compatibility tool shim. Steam runs Aurora's own copy under
  `compatibilitytools.d` directly, so the launcher is not in the game-launch
  path at all. `--wrap-compat-tool` puts `aurora-compat-launch` in front of it,
  applying the ICU fallback and library search path there too and logging every
  launch to `~/.local/state/aurora-sdtool/compat-tool.log`. The shim cannot
  block a game from starting: diagnostics are logged, never enforced, and every
  path ends in the same hand-off with argv untouched.
- `--doctor` verifies the payload against `SHA256SUMS` rather than only
  checking that the files exist.
- Uninstalling undoes the compatibility tool wrap before removing the launcher
  that manages it, instead of orphaning a shim inside Steam's directory.
- Automatic restoration of that wrap. Upstream's setup rewrites the tool
  manifest whenever it runs, silently undoing it; the launcher restores it on
  startup and again after Aurora exits.

### Fixed

- The desktop launcher ran this package's own copy of Aurora rather than the
  one Aurora installed into `compatibilitytools.d`. Since Aurora keeps its
  saved account and per-game settings beside its own installation, that meant a
  second, stateless instance asking for a sign-in that was already saved. It
  now hands over to the installed copy once one exists.

- Opening Aurora's Games tab crashed 3.2.0 outright — `ConfigureGameConfigVM`
  enumerates a `Configs` directory upstream never creates, and the resulting
  `DirectoryNotFoundException` is unhandled. The directory is now created.
- Wrapping rewrites every `commandline` entry in the tool manifest. Upstream
  ships two — `commandline` and `commandline_waitforexitandrun` — and games
  take the second, so wrapping only the first left the case that matters
  bypassing the shim entirely.

### Verified

Tested end to end on CachyOS (KDE Plasma 6.7.4, Wayland with XWayland, Steam
native, GE-Proton11-3) against Left 4 Dead:

- Steam honours the rewritten manifest and invokes the shim by name. All four
  invocations of a real launch went through it — `run` for the driver query and
  script evaluator, then `waitforexitandrun` for the game — and Aurora received
  the hand-off and opened its trainer.
- The shim `exec`s itself away, leaving no extra process in the tree.
- Restoring the wrap after upstream's setup reverts the manifest.
- Installing with nothing vendored fails with an explanation and no partial
  install; installing without the icon completes with a warning.
- `make check` and the GitHub Actions workflow pass.

### Notes

- Aurora is not distributed here and nothing in it is patched. Everything works
  around the upstream application from the outside; supply your own copy of the
  official archive with `scripts/vendor-upstream.sh`.
- Steam caches the tool manifest at client startup, so Steam must be restarted
  after wrapping before the shim is used.
- Mouse clicks in Aurora's own trainer window land slightly below the pointer.
  That is inside Aurora.exe under Proton and out of reach from here; display
  scaling, DPI and window frame extents were all measured and ruled out.
- x86-64 only, because upstream publishes no other architecture. `--doctor`
  reports this rather than failing obscurely.

[3.2.0]: https://github.com/franzjeger/aurora-sdtool-linux/releases/tag/v3.2.0

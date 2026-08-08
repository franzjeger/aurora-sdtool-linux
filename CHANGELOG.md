# Changelog

Changes to the Linux packaging. Upstream application changes are recorded
separately in [docs/upstream/Changelog.txt](docs/upstream/Changelog.txt).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions track the upstream release they package.

## [3.2.0] — 2026-08-08

First packaged release, built on upstream 3.2.0.

### Added

- `aurora-sdtool` launcher wrapper, which resolves the payload through
  symlinks, sets up the library search path and execs the upstream binary.
- Startup preflight for the fourteen shared libraries the payload needs.
  A missing library is reported by name with the install command for the
  detected distribution, instead of the .NET `DllNotFoundException` and core
  dump upstream produces.
- Display-server detection. A Wayland session without XWayland, or no display
  at all, is explained rather than crashing in `XOpenDisplay`.
- Automatic fallback to `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` when the
  system has no ICU library, which otherwise aborts .NET at startup.
- Per-user runtime directory. Aurora stores its settings next to its own
  executable, so a system-wide install into a read-only prefix loses every
  setting on restart. The wrapper mirrors the payload into
  `~/.local/share/aurora-sdtool/app` and runs it from there when the install
  prefix is not writable.
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
- Desktop entry, 256×256 hicolor icon and AppStream metadata.
- Packaging for Arch (`PKGBUILD`), Debian (`.deb`), RPM (`.spec`), AppImage and
  Flatpak.
- Wrapper test suite and a `make check` target running shellcheck, `bash -n`,
  `desktop-file-validate` and `appstreamcli validate`.
- GitHub Actions workflow running the checks and building packages.
- Documentation: installation, per-distribution notes, troubleshooting, and the
  redistribution and trademark position in `LEGAL.md`.

### Notes

- Upstream binaries are redistributed unmodified and unpatched. Everything here
  works around the upstream application from the outside.
- x86-64 only, because upstream publishes no other architecture. `--doctor`
  reports this rather than failing obscurely.

[3.2.0]: https://github.com/OWNER/aurora-sdtool-linux/releases/tag/v3.2.0

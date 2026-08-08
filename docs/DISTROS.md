# Distribution notes

The payload is a self-contained NativeAOT binary — no .NET runtime to install,
no framework version to match. What it needs from the host is a short list of
C libraries, an X11 display and, ideally, ICU.

Where a distribution needs something specific, it is here.

## Arch, CachyOS, Manjaro, EndeavourOS

Nothing special. Everything required is already pulled in by any desktop
install.

```bash
cd packaging/arch && makepkg -fi
```

CachyOS ships `proton-cachyos` into `/usr/share/steam/compatibilitytools.d`,
which upstream has scanned since 3.1.5, so those runners show up in Aurora's
Proton list without configuration.

## SteamOS (Steam Deck)

This is the platform upstream targets, with two wrinkles that matter here.

**The root filesystem is read-only.** `sudo scripts/install.sh --system` fails,
and even with `steamos-readonly disable` a system update reverts it. Install
into your home directory instead — the default:

```bash
scripts/install.sh
```

**Aurora must be configured from Desktop Mode.** Its UI cannot be reached from
Gaming Mode. Configure games in Desktop Mode, then switch back; the games
themselves launch normally from Gaming Mode.

The wrapper's runtime mirroring is not needed here, since `~/.local` is
writable, but it is harmless if you install somewhere read-only anyway.

## Debian, Ubuntu, Mint, Pop!_OS

```bash
make deb
sudo apt install ./dist/aurora-sdtool_*.deb
```

`libpng16-16` was renamed `libpng16-16t64` in the 64-bit time_t transition
(Ubuntu 24.04, Debian trixie). The package depends on either, so it installs on
both sides of the change.

Ubuntu's Steam is often the Snap, whose data lives in
`~/snap/steam/common/.local/share/Steam`. The wrapper reports that path in
`--doctor`, but point Aurora's installer at it explicitly — upstream does not
scan Snap locations.

## Fedora, RHEL, Rocky, Alma

```bash
make rpm
sudo dnf install ./dist/x86_64/aurora-sdtool-*.rpm
```

The spec disables debuginfo extraction and stripping: the payload is a prebuilt
binary with no build-id and no separable debug symbols, and `rpmbuild` fails
rather than skipping it otherwise.

RHEL and its rebuilds need RPM Fusion or Flathub for Steam itself. Aurora
installs and runs without it; it just has nothing to hook until Steam exists.

## openSUSE

The same RPM works. openSUSE splits library packages more finely than Fedora,
which is why `install_hint()` carries a separate `zypper` line — `libz1`,
`libbz2-1`, `libbrotlidec1`, `libX11-6` rather than Fedora's names.

Tumbleweed occasionally moves ahead of the ICU version .NET probes for. If
Aurora starts complaining about globalization after an ICU bump, the wrapper's
invariant fallback covers it automatically.

## NixOS

Neither the install script nor any package here fits NixOS: the payload is a
dynamically linked binary expecting an FHS layout that NixOS does not provide.
`--doctor` will report libraries as missing even when they exist in the store.

Run it inside an FHS environment. `steam-run` already provides everything:

```bash
nix-shell -p steam-run --run "steam-run ./src/aurora-sdtool"
```

For something permanent, wrap it in a `buildFHSUserEnv` derivation. A proper
Nix package would need `autoPatchelfHook` against the library list in
`src/aurora-sdtool`, which nobody has written yet — patches welcome.

## Alpine and other musl systems

Does not work. The payload is built against glibc, and NativeAOT binaries
cannot be run through a compatibility shim the way a script can. `gcompat` is
not sufficient.

Use a glibc distribution, or the Flatpak, which brings its own runtime.

## Containers and minimal installs

Two things are usually absent and both are handled:

- **No ICU** — the wrapper enables invariant globalization automatically rather
  than letting .NET abort at startup.
- **No fonts** — nothing can fix this from outside; the UI renders as empty
  boxes. Install any font package and run `fc-cache -f`.

An X11 display still has to be reachable, which for a container means passing
through `DISPLAY` and the X socket.

## Adding a distribution

If yours needs different package names, two places need updating:

1. `install_hint()` in `src/aurora-sdtool`, matched on `ID` and `ID_LIKE` from
   `/etc/os-release`.
2. This file.

See [CONTRIBUTING.md](../CONTRIBUTING.md).

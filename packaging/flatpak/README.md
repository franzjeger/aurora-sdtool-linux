# Flatpak

Read this before choosing Flatpak over a native package.

## The tradeoff

Aurora does two very different things:

1. Runs a desktop UI — perfectly happy in a sandbox.
2. Reaches into Steam's directories to install a compatibility tool, scan
   Proton builds, read game manifests and write launcher configuration —
   which a sandbox exists to prevent.

The manifest grants the narrowest set of paths that keeps (2) working:
`~/.steam`, `~/.local/share/Steam`, the Flatpak Steam data directory,
`/usr/share/steam` read-only, plus `~/Games` and `~/Downloads` for Aurora's own
install location.

That covers the common setups. It does **not** cover a Steam library on a
second drive, a game installed outside those paths, or a Steam installed
somewhere unusual. Add what you need:

```bash
flatpak override --user --filesystem=/mnt/games io.github.franzjeger.AuroraSDTool
```

If you find yourself adding several, a native package is the better answer.
Use `make arch`, `make deb` or `make rpm`.

## Status

Built and installed against the freedesktop 24.08 runtime, and verified from
inside the sandbox: `--doctor` reports no problems, the payload matches its
checksums, and the menu entry and icon export correctly.

One limitation is structural rather than a bug. Flatpak reserves `/usr` for the
runtime and refuses a `--filesystem=/usr/share/steam` override, so
distro-packaged Proton runners installed there — `proton-cachyos` and the like
— are invisible inside the sandbox. If you rely on those, use a native package.

Note also that `--state-dir` must be on the same filesystem as the build
directory; flatpak-builder refuses to start otherwise, which bites if the
checkout is on a network mount or a synced folder:

```bash
flatpak-builder --state-dir=/tmp/fp-state /tmp/fp-build packaging/flatpak/io.github.franzjeger.AuroraSDTool.yml
```

## Building

```bash
flatpak install -y flathub org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08
flatpak-builder --user --install --force-clean build packaging/flatpak/io.github.franzjeger.AuroraSDTool.yml
flatpak run io.github.franzjeger.AuroraSDTool --doctor
```

The build pulls the DejaVu fonts because the freedesktop runtime ships no
default font that Avalonia picks up, and the UI renders as empty boxes without
one.

## Flathub

This cannot be submitted to Flathub. Flathub requires that applications build
from source, and requires the submitter to control the domain in the
application ID. Neither holds: the payload is a proprietary prebuilt binary
from CheatHappens, redistributed under no granted licence.

Host it on your own remote, or install it locally with `--user` as above.

## Known limitations

- **No Wayland socket.** Avalonia's Linux backend is X11 only, so the manifest
  requests `--socket=x11` and relies on XWayland. Adding `--socket=wayland`
  changes nothing.
- **Steam must be running for some actions.** The sandbox does not block this,
  but a Flatpak Steam and a native Steam keep separate data directories, and
  Aurora sees whichever paths are exposed to it.
- **`--doctor` reports the sandbox, not the host.** Library checks run inside
  the runtime, which is the environment Aurora actually uses, so that is the
  useful answer — but it will not tell you what the host has installed.

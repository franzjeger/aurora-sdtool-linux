# Installing

## Which method

| You want | Use |
| --- | --- |
| The normal case, one machine | `scripts/install.sh` |
| Your distribution's package manager to own it | `make arch` / `make deb` / `make rpm` |
| One file you can copy to any machine | `make appimage` |
| A sandbox | [Flatpak](../packaging/flatpak/README.md) |

All of them install the same thing. The difference is who tracks the files.

## From the checkout

```bash
scripts/install.sh
```

Installs into `~/.local`:

```
~/.local/bin/aurora-sdtool
~/.local/lib/aurora-sdtool/{AuroraLauncher,libSkiaSharp.so,libHarfBuzzSharp.so,SHA256SUMS}
~/.local/share/applications/aurora-sdtool.desktop
~/.local/share/icons/hicolor/256x256/apps/aurora-sdtool.png
~/.local/share/metainfo/io.github.franzjeger.AuroraSDTool.metainfo.xml
~/.local/share/doc/aurora-sdtool/
```

No root, nothing outside your home directory. If `~/.local/bin` is not on your
`PATH`, the installer says so — the menu entry works regardless.

System-wide instead:

```bash
sudo scripts/install.sh --system     # /usr/local
```

Or anywhere:

```bash
scripts/install.sh --prefix /opt/aurora
```

The payload is verified against `vendor/SHA256SUMS` before anything is copied,
so a corrupted or altered payload fails the install rather than half-landing.

Verify afterwards:

```bash
aurora-sdtool --doctor
```

## Distribution packages

Each builds into `dist/`.

### Arch, CachyOS, Manjaro, SteamOS

```bash
cd packaging/arch && makepkg -fi
```

Or `make arch` to build without installing.

### Debian, Ubuntu, Mint

```bash
make deb
sudo apt install ./dist/aurora-sdtool_3.2.0-1_amd64.deb
```

Only `dpkg-deb` is needed, so the `.deb` can be built on a non-Debian host.

### Fedora, RHEL, openSUSE

```bash
make rpm
sudo dnf install ./dist/x86_64/aurora-sdtool-3.2.0-1*.rpm
```

`rpmbuild` runs in a private tree under `dist/`; `~/rpmbuild` is left alone.

### AppImage

```bash
make appimage
chmod +x dist/aurora-sdtool-3.2.0-x86_64.AppImage
./dist/aurora-sdtool-3.2.0-x86_64.AppImage
```

Needs `appimagetool` on `PATH`, or dropped into `packaging/appimage/`; the
build script prints the download command if it cannot find one.

The AppImage bundles the payload and the packaging but uses the host's X11 and
font libraries — the same ones any desktop already has. `--doctor` names
anything missing.

Because an AppImage mount is read-only, the wrapper mirrors the payload into
`~/.local/share/aurora-sdtool/app` on first run. That is where Aurora keeps its
settings, so they survive replacing the AppImage with a newer one.

## Building for another machine

Everything except the Arch package builds without the target distribution:

```bash
make deb        # needs dpkg-deb
make rpm        # needs rpmbuild
make appimage   # needs appimagetool
```

Copy the result over and install it there. All output is architecture
`x86_64` — upstream publishes nothing else.

## Without the payload

If `vendor/` was stripped before publication, supply the official archive:

```bash
scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
```

That extracts the payload, checks it is an x86-64 ELF binary, records
checksums, refreshes the upstream README, changelog and icon, and regenerates
`vendor/UPSTREAM.md`. Then install normally.

## Upgrading

```bash
scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
scripts/install.sh
```

Your settings live in `~/.config/aurora-sdtool` and in Aurora's own install
directory, and are not touched. The wrapper notices the payload changed and
refreshes its runtime copy on the next launch.

Aurora also updates itself in place. When it does, the running version moves
ahead of what `vendor/` holds — harmless, and re-vendoring resyncs them.

## Uninstalling

```bash
scripts/uninstall.sh                  # per-user
sudo scripts/uninstall.sh --system    # system-wide
scripts/uninstall.sh --purge          # also delete settings, logs, runtime copy
```

This removes the *tool*. Aurora itself, and the Steam compatibility tool it
registers, are removed from Aurora's own **Tools** tab — do that before
uninstalling, or clean up manually afterwards:

- the Aurora folder you chose during Aurora's install
- `AuroraLauncher` under Steam's `compatibilitytools.d`

# Aurora SD Tool for Linux

Linux packaging for the **Aurora Steam Deck Tool** by CheatHappens — the
utility that installs the Aurora game trainer and registers it as a Steam Play
compatibility tool, so games launched from Steam start with Aurora attached.

Upstream ships a zip aimed at one machine: a Steam Deck running SteamOS in
Desktop Mode. This repository turns it into an application that installs and
behaves like any other Linux desktop program, on any distribution.

> [!IMPORTANT]
> Unofficial packaging. Not affiliated with or endorsed by CheatHappens or
> Valve. The binaries in `vendor/` are proprietary and redistributed as-is —
> read [LEGAL.md](LEGAL.md) before publishing this repository anywhere.

## What this adds

The upstream archive is seven files with a `Readme.txt` that says "extract
somewhere and double-click". That works on a Steam Deck and falls apart
elsewhere. Concretely, this repository fixes:

| Upstream behaviour | Here |
| --- | --- |
| Files must sit together in one writable directory, run from that directory | Installs to a normal prefix; `aurora-sdtool` runs from anywhere on `$PATH` |
| Settings are written next to the executable, so a `/usr` install silently loses them on every restart | Payload is mirrored into `~/.local/share/aurora-sdtool` when the install prefix is read-only |
| A missing system library surfaces as an unhandled .NET exception and a core dump | Preflight check names the missing library and prints the install command for your distro |
| On Wayland without XWayland it core-dumps on `XOpenDisplay` | Detects the session and explains what to install |
| No ICU on the system aborts startup | Falls back to invariant globalization automatically |
| No desktop entry; upstream creates one by writing to `~/Desktop` | Proper `.desktop` entry, hicolor icon and AppStream metadata |
| Config, cache and logs all live in the install directory | XDG base directories |
| No uninstaller beyond a button inside the app | `scripts/uninstall.sh`, with `--purge` |
| Zip only | Arch, Debian, RPM, AppImage and Flatpak packaging |

Nothing in the upstream binary is patched or modified. All of this is done by
the wrapper around it.

## Requirements

- x86-64 Linux — upstream publishes no other architecture
- An X11 session, or a Wayland session with XWayland
- Steam, for the parts of Aurora that hook games
- A CheatHappens account

Runtime libraries: `fontconfig`, `freetype`, `expat`, `zlib`, `bzip2`,
`libpng`, `brotli`, `libX11`, `libxcb`, `libXau`, `libXdmcp`, `libstdc++`.
ICU is used when present. All of these are already installed on any normal
desktop system; `aurora-sdtool --doctor` tells you if something is missing.

## Install

### From this checkout

```bash
scripts/install.sh
```

That installs into `~/.local` — no root, no system files touched. For all
users:

```bash
sudo scripts/install.sh --system
```

Then check the machine is ready:

```bash
aurora-sdtool --doctor
```

### Distribution packages

```bash
make arch       # Arch, CachyOS, Manjaro, SteamOS  -> .pkg.tar.zst
make deb        # Debian, Ubuntu, Mint             -> .deb
make rpm        # Fedora, RHEL, openSUSE           -> .rpm
make appimage   # anything                         -> .AppImage
```

Output lands in `dist/`. See [docs/INSTALL.md](docs/INSTALL.md) for Flatpak and
for building on a machine other than the target.

### Bring your own payload

If `vendor/` is empty because the payload was stripped before publishing,
supply the official archive yourself:

```bash
scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
scripts/install.sh
```

## Use

Launch **Aurora SD Tool** from your application menu, or run `aurora-sdtool`.

> [!WARNING]
> **First launch installs Aurora immediately — it does not wait for you to
> press Install.** On a system upstream does not recognise as a Steam Deck it
> skips the confirmation, downloads Aurora (~170 MB) into `~/Downloads/Aurora`,
> registers the `AuroraLauncher` compatibility tool with Steam, drops a
> shortcut on your desktop, and then closes and restarts Steam. Verified on
> 3.2.0. If that is not what you want, do not launch it — there is no
> "just look at it" mode.
>
> Everything it creates is listed under [Undoing an install](#undoing-an-install).

After it installs, log in with your CheatHappens account. Then hook a game
through Steam:

1. Right-click the game in your Steam library → **Properties**
2. **Compatibility** → tick *Force the use of a specific Steam Play
   compatibility tool*
3. Pick **Aurora Launch**
4. Launch the game

Per-game options — Proton version, which trainer to open, whether Aurora
auto-activates — live in the **Games** tab. Non-Steam launchers such as Ubisoft
Connect and the Epic Games Store are covered in
[docs/upstream/Readme.txt](docs/upstream/Readme.txt).

### Command line

```
aurora-sdtool             launch the application
aurora-sdtool --doctor    check this system for everything Aurora needs
aurora-sdtool --where     print payload, runtime, config and state paths
aurora-sdtool --log       print the path of the wrapper log
aurora-sdtool --version   print version information
aurora-sdtool --help      full option list

aurora-sdtool --wrap-compat-tool     cover the game-launch path too
aurora-sdtool --unwrap-compat-tool   undo that
```

Anything else is passed through to the upstream launcher unchanged.

### Covering the game-launch path

`aurora-sdtool` is the desktop application. It is **not** what runs when you
launch a game — Steam executes Aurora's own copy of itself under
`compatibilitytools.d` directly, so none of the environment fixes above apply
there. A missing library on that path produces a .NET stack trace somewhere in
Steam's logs and nothing else.

Once Aurora has registered itself with Steam:

```bash
aurora-sdtool --wrap-compat-tool
```

That puts a small shim in front of Aurora's launcher and repoints the tool
manifest at it. The shim applies the ICU fallback and library search path, and
records every game launch in `~/.local/state/aurora-sdtool/compat-tool.log`.
Restart Steam afterwards so it re-reads the manifest.

The shim is deliberately incapable of stopping a game from launching: problems
are logged, never enforced, and every path ends in the same hand-off with your
arguments untouched. `--unwrap-compat-tool` restores the original manifest from
the backup it keeps.

Opening the desktop app re-runs upstream's setup, which rewrites the manifest
and drops the wrap — as does an Aurora self-update. The launcher restores it
by itself: once on startup, and again after Aurora exits. `--doctor` reports
the state either way, and `--wrap-compat-tool` is always safe to re-run.

Because of that, `aurora-sdtool` stays running in the background while a
wrapped Aurora is open, so it can put the wrap back afterwards. Without a wrap
it hands the process over and leaves nothing behind.

## Layout

```
src/aurora-sdtool        the launcher wrapper — where the Linux support lives
vendor/                  upstream payload, verbatim (see LEGAL.md)
scripts/                 install, uninstall, payload refresh
share/                   desktop entry, icon, AppStream metadata
packaging/               Arch, Debian, RPM, AppImage, Flatpak
docs/                    installation, distro notes, troubleshooting
tests/                   wrapper test suite
```

Files the wrapper owns at runtime:

| Path | Contents |
| --- | --- |
| `~/.config/aurora-sdtool/env` | Optional overrides, sourced at startup |
| `~/.local/share/aurora-sdtool/app` | Per-user payload copy, when the prefix is read-only |
| `~/.local/state/aurora-sdtool/aurora-sdtool.log` | Wrapper log |

### Undoing an install

`scripts/uninstall.sh` removes this packaging. Aurora installs *itself*
elsewhere, and nothing here tracks those files — remove them from Aurora's
**Tools** tab, or by hand. On 3.2.0 a first launch creates exactly:

```
~/Downloads/Aurora/                                    # or wherever you pointed it
~/.local/share/Steam/compatibilitytools.d/AuroraLauncher/
~/Desktop/Aurora Launcher.desktop
```

Deleting those three puts the system back. Leave any *other* directory under
`compatibilitytools.d` alone — that is where Proton builds live.

## Updating

When CheatHappens publishes a new build:

```bash
scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
$EDITOR VERSION CHANGELOG.md
make check
scripts/install.sh
```

Aurora also updates itself in place, so the vendored payload can drift behind
what is actually running. That is fine — re-vendoring resets it.

## Development

```bash
make            # list targets
make check      # shellcheck, bash -n, desktop and AppStream validation, tests
make test       # wrapper test suite only
make verify     # confirm vendor/ matches SHA256SUMS
```

The wrapper runs from the checkout without installing anything — it finds
`vendor/` on its own:

```bash
src/aurora-sdtool --doctor
```

Contribution notes are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Troubleshooting

Start with `aurora-sdtool --doctor`. It checks architecture, payload integrity,
every required library, the display server, Steam locations and desktop
integration, and prints a fix for each problem it finds.

Common cases are written up in
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md); per-distribution notes,
including SteamOS's read-only root, are in [docs/DISTROS.md](docs/DISTROS.md).

## Licence

MIT for the packaging — see [LICENSE](LICENSE). The upstream payload in
`vendor/` is proprietary — see [LEGAL.md](LEGAL.md).

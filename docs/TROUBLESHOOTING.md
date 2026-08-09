# Troubleshooting

Start here:

```bash
aurora-sdtool --doctor
```

It checks the architecture, the payload and its checksums, every library the
payload needs, ICU, the display server, every Steam location it knows
about, and desktop integration — and prints a fix for each problem it finds.
Most of what follows is the long form of one of its lines.

Three logs exist and they answer different questions:

| Log | Written by | Covers |
| --- | --- | --- |
| `~/.local/state/aurora-sdtool/aurora-sdtool.log` | this wrapper | starting the desktop app: paths, missing libraries, runtime sync |
| `~/.local/state/aurora-sdtool/compat-tool.log` | the compat shim | launching a game through Steam — only after `--wrap-compat-tool` |
| Aurora's own log, via its **Tools** tab | upstream | the application: login, Proton, game hooking |

The second exists because Steam runs Aurora's compatibility tool directly and
never touches `aurora-sdtool`. Without the wrap, that path produces no
diagnostics of its own — see
[Nothing is logged when I launch a game](#nothing-is-logged-when-i-launch-a-game).

---

## It does not start

### "required system libraries are missing"

The wrapper lists each missing library and the exact install command for your
distribution. Run it, then `aurora-sdtool --doctor` again.

Without the wrapper you would see a .NET `DllNotFoundException` and a core
dump, which is what upstream produces and why this check exists.

### "A Wayland session was detected but DISPLAY is not set"

Aurora is an Avalonia application, and Avalonia's Linux backend renders through
X11 only. On Wayland that means XWayland, and XWayland is what sets `DISPLAY`.

```bash
sudo pacman -S xorg-xwayland          # Arch, CachyOS, SteamOS
sudo apt install xwayland             # Debian, Ubuntu
sudo dnf install xorg-x11-server-Xwayland   # Fedora
```

Log out and back in afterwards. Nothing else about the session needs to change
— Aurora runs perfectly well through XWayland.

### "No graphical display found"

There is no desktop session. Aurora cannot run on a TTY, and over SSH it needs
X11 forwarding (`ssh -X`).

On a Steam Deck, switch to Desktop Mode first. Aurora's UI cannot be used from
Gaming Mode; Gaming Mode is where the *games* run once Aurora is configured.

### "Could not find the Aurora payload"

The launcher is installed but the application files are not. Either the install
was partial, or the payload was never vendored.

```bash
aurora-sdtool --where                                  # what it looked for
scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
scripts/install.sh
```

For an unusual layout, point it at the files directly:

```bash
echo 'export AURORA_SDTOOL_LIBDIR=/path/to/payload' >> ~/.config/aurora-sdtool/env
```

### "The vendored payload does not match vendor/SHA256SUMS"

The payload differs from what was recorded. Usually a truncated download or an
interrupted copy. Re-vendor from a freshly downloaded archive.

If you *intended* to change it — you should not have to, but if you did — run
`scripts/vendor-upstream.sh` again to re-record the checksums.

### It exits immediately with no message at all

Check the wrapper log:

```bash
cat "$(aurora-sdtool --log)"
```

If the wrapper's own steps all succeeded, the crash is inside the upstream
binary and belongs to CheatHappens. Reproduce it in a terminal so the .NET
exception is visible:

```bash
aurora-sdtool 2>&1 | tee /tmp/aurora-crash.log
```

---

## It installed Aurora without asking

Expected, and not something this packaging does. On a system upstream does not
recognise as a Steam Deck, first launch skips the confirmation and runs the
whole install — this is the "bypass the install dialog" behaviour upstream
added in 2.5.0. Verified on 3.2.0: the setup screen appears with every step
already done, then Steam is closed and restarted.

There is no flag to open the UI without installing. To undo it, close Aurora
and delete the three things it created:

```bash
rm -rf ~/Downloads/Aurora
rm -rf ~/.local/share/Steam/compatibilitytools.d/AuroraLauncher
rm -f  ~/Desktop/"Aurora Launcher.desktop"
```

Substitute your own path for `~/Downloads/Aurora` if you changed it.

**Delete nothing else under `compatibilitytools.d`** — Proton builds live
there, and removing one breaks every game configured to use it.

### "Permission denied" when installing system-wide, or when installing the package

Not a bug in the scripts — root cannot read your checkout.

A FUSE mount without `allow_other` (OneDrive, Dropbox, `sshfs`, `rclone`) is
visible only to the user who mounted it. Anything running as root sees nothing
there, so both of these fail with a bare `Permission denied` that says nothing
about the real cause:

```bash
sudo scripts/install.sh --system
sudo pacman -U packaging/arch/aurora-sdtool-*.pkg.tar.zst
```

`scripts/install.sh --system` now detects this and explains it. For the package,
copy it somewhere local first:

```bash
cp packaging/arch/aurora-sdtool-*.pkg.tar.zst /tmp/
sudo pacman -U /tmp/aurora-sdtool-*.pkg.tar.zst
```

Or work from a local clone entirely, which avoids every variant of this:

```bash
git clone . /tmp/aurora-build && cd /tmp/aurora-build
scripts/vendor-upstream.sh /path/to/Aurora_SDTool.zip
```

A per-user install is unaffected — it never involves root.

## It starts but misbehaves

### Settings reset on every restart

Aurora writes its settings next to its own executable. If it is running from a
read-only location, every setting is lost on restart. Upstream 3.2.0 warns
about this in its activity feed but cannot fix it.

The wrapper does: when the install prefix is not writable, the payload is
mirrored into `~/.local/share/aurora-sdtool/app` and run from there.

If this is still happening, something forced the mirror off:

```bash
aurora-sdtool --where               # is "runtime" inside your home?
grep NO_SYNC ~/.config/aurora-sdtool/env
```

Remove `AURORA_SDTOOL_NO_SYNC=1` if it is set, and check the home partition is
not full or mounted read-only.

### Text renders as boxes, or the UI is blank

A font problem. Skia needs at least one usable font through fontconfig:

```bash
fc-list | head
```

If that is empty, install a font (`ttf-dejavu`, `fonts-dejavu-core`,
`dejavu-sans-fonts`) and run `fc-cache -fv`.

This mostly shows up in containers and on minimal installs, and inside the
Flatpak, which is why that manifest bundles DejaVu.

### Sorting or date formatting looks wrong

The wrapper enabled invariant globalization because the system has no ICU
library. Everything works; locale-specific behaviour falls back to English.

Install ICU (`icu`, `libicu`, `libicu72`) and it stops. Confirm with
`aurora-sdtool --doctor`, which reports ICU explicitly.

### The window is too large, or controls are cut off

The UI targets the Steam Deck's 1280×800. `--doctor` warns below 768 logical
pixels. On a HiDPI display, scale it down:

```bash
echo 'export AVALONIA_GLOBAL_SCALE_FACTOR=0.8' >> ~/.config/aurora-sdtool/env
```

---

## Steam and games

These are upstream's domain — the wrapper only gets Aurora running. Report them
to CheatHappens. The common ones:

### "Aurora Launch" is missing from Steam's compatibility list

Restart Steam. It reads `compatibilitytools.d` only at startup.

If it is still missing, check the entry actually landed somewhere Steam looks:

```bash
aurora-sdtool --doctor              # lists every compatibilitytools.d found
ls ~/.steam/steam/compatibilitytools.d/
```

A Flatpak Steam reads `~/.var/app/com.valvesoftware.Steam/data/Steam` and
ignores `~/.steam` entirely. Point Aurora's installer at the Flatpak path if
that is the Steam you use.

### Nothing is logged when I launch a game

`aurora-sdtool` is the desktop application. Steam launches a game by running
Aurora's own copy under `compatibilitytools.d` directly, so nothing this
project does is in that path by default.

```bash
aurora-sdtool --wrap-compat-tool   # then restart Steam
```

Afterwards each launch is recorded in
`~/.local/state/aurora-sdtool/compat-tool.log`, and that path also gets the ICU
fallback and library search path the desktop launcher has.

Upstream's setup rewrites the manifest every time it runs, which drops the
wrap. The launcher puts it back by itself — on startup, and again once Aurora
has exited. `aurora-sdtool --doctor` shows the current state, and
`--wrap-compat-tool` is safe to re-run at any time.

This is why `aurora-sdtool` stays running while a wrapped Aurora is open: it
waits for the last launcher to exit before restoring. Without a wrap it execs
and leaves no process behind.

The shim cannot prevent a game from starting — every problem it finds is
logged, never enforced, and it always hands off with your arguments unchanged.
To remove it entirely, `--unwrap-compat-tool` restores the original manifest.

### The game starts but Aurora does not

Check the game is set to *Force the use of a specific Steam Play compatibility
tool* → **Aurora Launch**, and that the game has a per-game entry in Aurora's
**Games** tab. Aurora's own log records why it declined to start.

### Proton versions are missing from the list

Aurora scans Steam library folders, Flatpak installs, and — since 3.1.5 —
`/usr/share/steam/compatibilitytools.d`, which is where distro-packaged runners
like `proton-cachyos` land. A Proton in some other directory will not appear.

---

## Reporting a bug

Wrapper, installer or packaging — report it here, with:

```bash
aurora-sdtool --doctor
aurora-sdtool --version
cat "$(aurora-sdtool --log)"
```

Aurora itself — report it to CheatHappens. The binary is closed source and
nothing in this repository can change its behaviour.

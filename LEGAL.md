# Legal notes

Read this before publishing this repository anywhere public.

## What is in here, and who owns it

This repository mixes two things under different terms.

| Path | Origin | Licence |
| --- | --- | --- |
| `src/`, `scripts/`, `packaging/`, `share/`, `docs/`, `tests/` | Written for this repository | [MIT](LICENSE) |
| `vendor/`, `docs/upstream/`, `share/icons/…/aurora-sdtool.png` | Redistributed verbatim from CheatHappens | Proprietary — all rights reserved by CheatHappens |

Nothing in `vendor/` was built from source in this repository. There is no
source: `AuroraLauncher` is a closed-source .NET NativeAOT binary published by
CheatHappens, and `libSkiaSharp.so` / `libHarfBuzzSharp.so` are the SkiaSharp
and HarfBuzzSharp native libraries as shipped in the official archive. They are
byte-for-byte identical to the upstream release; checksums are recorded in
[`vendor/SHA256SUMS`](vendor/SHA256SUMS) and
[`vendor/UPSTREAM.md`](vendor/UPSTREAM.md).

## Redistribution

**CheatHappens has not granted redistribution rights for Aurora, and this
repository does not claim any.** Nothing of theirs is published here.

This repository contains packaging only. The following are deliberately absent
from the repository and from its git history, and are listed in `.gitignore`:

- `vendor/AuroraLauncher`, `vendor/libSkiaSharp.so`, `vendor/libHarfBuzzSharp.so`
- `share/icons/hicolor/256x256/apps/aurora-sdtool.png` (CheatHappens artwork)
- `docs/upstream/*.txt` (upstream's own README and changelog)

Supply your own copy of the official archive, which provides all of them:

```bash
scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
```

Everything degrades gracefully without it: the install script refuses to run
and says why, and a missing icon downgrades to a generic one rather than
failing. `vendor/SHA256SUMS` and `vendor/UPSTREAM.md` remain, so you can verify
that what you supplied matches the build this packaging was tested against.

## Trademarks

"Aurora", "CheatHappens" and the Aurora icon belong to CheatHappens. "Steam",
"Steam Deck", "Steam Play" and "Proton" belong to Valve Corporation. This is an
unofficial packaging effort and is not affiliated with, endorsed by, or
supported by either company.

Because of that, the AppStream component ID and the Flatpak application ID are
`io.github.franzjeger.AuroraSDTool` — the `io.github.` namespace reserved for
projects hosted on GitHub — rather than anything belonging to CheatHappens.
Change it if you fork this to a different home.

## Using the software

Aurora requires a CheatHappens account, and some functionality requires a paid
subscription. This packaging does not bypass, patch or modify any part of the
upstream binary — it only changes where the files live and how they are
launched. Account terms are between you and CheatHappens.

Game trainers modify the memory of running games. Using them in multiplayer
games commonly violates the game's terms of service and can result in a ban.
That is your call to make, not this repository's.

## How Aurora stores your account credentials

Worth knowing before you log in, because it is not obvious and this packaging
cannot change it.

After a successful login Aurora writes its settings to a plain JSON file inside
the Steam compatibility tool directory it installs:

```
~/.local/share/Steam/compatibilitytools.d/AuroraLauncher/globalconfig.json
```

That file contains your CheatHappens **email address in clear text** and a
**64-character hexadecimal digest of your password**, consistent with an
unsalted SHA-256 — no salt is stored alongside it. It is written with mode
`0644` in a directory with mode `0755`, so **every local account on the machine
can read it**.

What that means in practice:

- On a single-user desktop the exposure is limited, but the file is still
  readable by anything running as another local user, and by backup or sync
  tools that copy `~/.local/share` wholesale.
- A digest is not encryption. If the password is weak or reused, a plain
  SHA-256 of it is recoverable from public rainbow tables in seconds.
- **Do not reuse your CheatHappens password anywhere else.** That is the single
  useful mitigation available to you.

Tightening the permissions yourself is possible but not durable — Aurora
rewrites the file, and its installer replaces the whole directory on update:

```bash
chmod 600 ~/.local/share/Steam/compatibilitytools.d/AuroraLauncher/globalconfig.json
```

This is upstream behaviour, observed in 3.2.0. Nothing in this repository reads,
writes, transmits or modifies that file; it is documented here only so the
choice to log in is an informed one. Report it to CheatHappens if it concerns
you — they are the only ones who can fix it.

## Bug reports

Report bugs in the Aurora application itself to CheatHappens — they cannot act
on reports filed here, and this repository cannot fix them either, since the
binary is closed source.

Report bugs in the launcher wrapper, the install scripts or the packaging here.
Attach the output of:

```bash
aurora-sdtool --doctor
```


```bash
aurora-sdtool --doctor
```

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

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

**CheatHappens has not granted redistribution rights for these binaries, and
this repository does not claim any.** Keeping the payload in a private
repository for your own machines is one thing; publishing it is another.

If you intend to make this repository public:

1. Ask CheatHappens for permission to redistribute the payload, **or**
2. Remove `vendor/` from the published history and ship packaging only.

Option 2 is supported out of the box. Every script degrades gracefully when the
payload is absent, and a user supplies their own copy with:

```bash
scripts/vendor-upstream.sh ~/Downloads/Aurora_SDTool.zip
```

To strip the payload before publishing:

```bash
git rm -r --cached vendor/AuroraLauncher vendor/libSkiaSharp.so vendor/libHarfBuzzSharp.so
printf 'vendor/AuroraLauncher\nvendor/*.so\n' >> .gitignore
```

Note that `git rm --cached` only removes the files from the current commit —
they stay in history. Use `git filter-repo` if the repository already has
public commits containing them.

## Trademarks

"Aurora", "CheatHappens" and the Aurora icon belong to CheatHappens. "Steam",
"Steam Deck", "Steam Play" and "Proton" belong to Valve Corporation. This is an
unofficial packaging effort and is not affiliated with, endorsed by, or
supported by either company.

Because of that, the AppStream component ID and the Flatpak application ID use
the packager's own domain (`io.github.franzjeger.AuroraSDTool`) rather than a CheatHappens
domain. Change it to a domain you control before publishing.

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

# Vendored upstream payload

These files are redistributed verbatim from the official Aurora Steam Deck
Tool archive published by CheatHappens. They are **not** built from this
repository and are **not** covered by its licence — see [LEGAL.md](../LEGAL.md).

| Field | Value |
| --- | --- |
| Upstream version | `3.2.0` |
| Source archive | `Aurora_SDTool.zip` |
| Archive SHA-256 | `d11cb1779a1f543800d7373212b6ebd47e4eba1e331dba864a9f81f6341c4124` |
| Architecture | `x86-64` |
| Runtime | .NET NativeAOT, Avalonia UI (X11 backend) |

## Files

| File | SHA-256 |
| --- | --- |
| `AuroraLauncher` | `ba09fa78c93bb92fd71eee0857cf8e64931be760e7fa649b72178b72eb941115` |
| `libSkiaSharp.so` | `66c856eaf1a47a00b23204c30c6ee407987bf5086ecc0a1a6b4fd67526b0cd02` |
| `libHarfBuzzSharp.so` | `1d5c3afef13545bf34bf8f068b14e25ee619c3b6dee235c44e260fe61cb24018` |

## Refreshing

```bash
scripts/vendor-upstream.sh /path/to/Aurora_SDTool.zip
```

Then bump `VERSION` to match the upstream version and record the change in
[CHANGELOG.md](../CHANGELOG.md).

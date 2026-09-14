# Clickwrap demo files

| File | Role |
| --- | --- |
| `tnc-clickwrap-demo.mp4` | ~18s dummy Agree flow: unchecked checkbox → check → Agree → “You're in. Thanks for reading.” |
| `tnc-clickwrap-demo.mp4.b64` | Full base64 of the mp4 (over GitHub contents 1MB — use the parts) |
| `tnc-clickwrap-demo.mp4.b64.part1` / `.part2` | Split base64, each under 800_000 chars |
| `tnc-clickwrap-demo.mp4.b64.manifest` | original_bytes, sha256, ordered part paths |
| `tnc-agree.png` | Still of Studio Terms with the checkbox unchecked |
| `tnc-agree.png.b64` | Base64 of the still |

Decode a `.b64` file with `base64 -d tnc-clickwrap-demo.mp4.b64 > tnc-clickwrap-demo.mp4`.

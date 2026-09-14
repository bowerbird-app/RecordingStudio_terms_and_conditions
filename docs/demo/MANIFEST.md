# Clickwrap demo files

Stills retaken 2026-09-14 after Users Auth sign-in and no-Card terms/write/helper screens.

| File | Role |
| --- | --- |
| `tnc-clickwrap-demo.mp4` | ~18s dummy Agree flow: unchecked checkbox → check → Agree → “You're in. Thanks for reading.” |
| `tnc-clickwrap-demo.mp4.b64` | Full base64 of the mp4 (over GitHub contents 1MB — use the parts) |
| `tnc-clickwrap-demo.mp4.b64.part1` / `.part2` | Split base64, each under 800_000 chars |
| `tnc-clickwrap-demo.mp4.b64.manifest` | original_bytes, sha256, ordered part paths |
| `tnc-agree.png` | Still of Studio Terms (multi-section sample body) |
| `tnc-agree.png.b64` | Base64 of the still |
| `tnc-agree-helper.png` | Dummy `/agree_helper` code example + checkbox |
| `tnc-admin-terms.png` | Admin Terms Flatpack table |
| `tnc-admin-richtext.png` | Admin edit TipTap body |

Rebuild the mp4 from parts:

```
cat docs/demo/tnc-clickwrap-demo.mp4.b64.part1 docs/demo/tnc-clickwrap-demo.mp4.b64.part2 \
  | base64 -d > tnc-clickwrap-demo.mp4
```

Then check `sha256sum` against `tnc-clickwrap-demo.mp4.b64.manifest`.

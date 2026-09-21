# Clickwrap demo files

Stills retaken 2026-09-21 after continue-notice Modal and Agree Collapse restyle.

| File | Role |
| --- | --- |
| `tnc-clickwrap-demo.mp4` | Dummy Agree flow from an earlier cut |
| `tnc-clickwrap-demo.mp4.b64` | Full base64 of the mp4 (over GitHub contents 1MB — use the parts) |
| `tnc-clickwrap-demo.mp4.b64.part1` / `.part2` | Split base64, each under 800_000 chars |
| `tnc-clickwrap-demo.mp4.b64.manifest` | original_bytes, sha256, ordered part paths |
| `tnc-agree.png` | Agree: no PageNav, closed Collapse titled with the live Terms heading, pre-checked checkbox and Agree |
| `tnc-agree.png.b64` | Base64 of the Agree still |
| `tnc-agree-helper.png` | Dummy `/agree_helper` checkbox form plus continue notice |
| `tnc-agree-helper.png.b64` | Base64 of the helper still |
| `tnc-continue-notice-modal.png` | Continue-notice Flatpack Modal with `FlatPack::Content` body |
| `tnc-continue-notice-modal.png.b64` | Base64 of the modal still |
| `tnc-signup-agree.png` | Users create-password step with the Agree checkbox in `extra_fields` |
| `tnc-signup-agree.png.b64` | Base64 of the signup still |
| `tnc-admin-terms.png` | Admin Terms Flatpack table |
| `tnc-admin-richtext.png` | Admin edit TipTap body |

Rebuild the mp4 from parts:

```
cat docs/demo/tnc-clickwrap-demo.mp4.b64.part1 docs/demo/tnc-clickwrap-demo.mp4.b64.part2 \
  | base64 -d > tnc-clickwrap-demo.mp4
```

Then check `sha256sum` against `tnc-clickwrap-demo.mp4.b64.manifest`.

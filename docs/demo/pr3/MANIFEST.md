# PR #3 dummy demos (receipts, re-gate, Admin)

Captured 2026-09-15 from the PR branch dummy at `http://127.0.0.1:3000` (Flatpack `rounded`, CSS loaded). Viewport 1280×800.

| File | Caption |
| --- | --- |
| `agree_before_scroll.png` | Agree screen, dummy `require_scroll_to_end` on. Top of live Studio Terms; Agree is below the fold. |
| `agree_after_scroll.png` | Same screen after the end sentinel is scrolled into view. Agree is enabled (dark primary). Checkbox still required. |
| `agree_ticked.png` | End of clickwrap: box ticked, Agree enabled. Scroll-to-end does not imply reading. |
| `agree_regate.png` | Re-gate Accept after an older snapshot was accepted and a new live version published. No on-page “Terms updated” Alert. Continue-notice + **Continue**, calendar date subtitle, flash “We've updated our Terms and Conditions”. First-time Accept has no flash. |



| `dummy_config.png` | Dummy `/docs/config` (A6): product knobs `mount_path`, `require_scroll_to_end`, `capture_request_provenance`. No template `api_key` / `enable_feature_x` / `timeout`. |
| `admin_terms_index.png` | Engine Admin Terms table after the demo accept (Agrees = 1). |
| `admin_term_show.png` | Admin term show: live copy, Users / Edit / Publish. Recording and snapshot ids only. |
| `admin_term_users.png` | Users receipts for this term. Person + agreed time. **`body_digest` is backend-only** (Acceptance column + `receipt_contract`); not drawn on this table. |

## Not captured

- **Admin hub / Who agreed screen:** `/admin` did not render in headless Chrome (`chrome-error`). Engine Terms index/show/Users cover the Admin surfaces this PR actually touches.
- **Disabled Agree in the same frame as the sentinel:** at 1280×800 the empty sentinel sits on the checkbox, so scrolling the end into view also unlocks Agree. The before/after pair is the honest demo.
- **`body_digest` UI:** none. SHA-256 is stored on `recording_studio_terms_and_conditions_acceptances.body_digest` at `accept!` time. Do not invent a digest column on Users.

Copies also live under `/opt/cursor/artifacts/tnc-pr3/`.

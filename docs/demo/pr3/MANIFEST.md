# PR #3 dummy demos (A6 ∥ A5 ∥ A1 ∥ A2 ∥ A3 ∥ A4 ∥ B1 ∥ B2 ∥ B3 ∥ B5)

Captured 2026-09-15 from the PR branch dummy at `http://127.0.0.1:3000` (Flatpack `rounded`, CSS loaded). Viewport 1280×800.

| File | Caption |
| --- | --- |
| `agree_before_scroll.png` | Agree screen, dummy `require_scroll_to_end` on. Top of live Studio Terms; Agree is below the fold. |
| `agree_after_scroll.png` | Same screen after the end sentinel is scrolled into view. Agree is enabled (dark primary). Checkbox still required. |
| `agree_ticked.png` | End of clickwrap: box ticked, Agree enabled. Scroll-to-end does not imply reading. |
| `agree_regate.png` | Re-gate Agree after an older snapshot was accepted and a new live version published. Flatpack Alert **Terms updated**, calendar date `15 Sep 2026`, optional `change_note` (“We added a kindness clause.”). First-time Agree does not show this Alert. |
| `agree_pending_kinds.png` | B3: Agree lists pending **Studio Terms** and **Booth privacy**. One checkbox (“I agree to Terms and Privacy.”). One scroll sentinel still sits after the last body. Mixed re-gate Alert stays on the kinds that changed. |
| `dummy_config.png` | Dummy `/docs/config` (A6): product knobs `mount_path`, `require_scroll_to_end`, `capture_request_provenance`. No template `api_key` / `enable_feature_x` / `timeout`. |
| `admin_terms_index.png` | Engine Admin Terms table after the demo accept (Agrees = 1). |
| `admin_terms_coverage.png` | B5: Coverage per category (Terms live / Privacy live / Usage —) plus the unfiltered list with Category column. |
| `admin_terms_filter_privacy.png` | B5: Category filter `privacy` — list shows Booth privacy only. Coverage table still lists every category. |
| `admin_term_show.png` | Admin term show: live copy, Users / Edit / Publish. Recording and snapshot ids only. |
| `admin_term_users.png` | Users receipts for this term. Person + agreed time. **`body_digest` is backend-only** (Acceptance column + `receipt_contract`); not drawn on this table. |

## Not captured

- **Admin hub / Who agreed screen:** `/admin` did not render in headless Chrome (`chrome-error`). Engine Terms index/show/Users cover the Admin surfaces this PR actually touches. Kind is also a column on the Who agreed Admin screen.
- **Disabled Agree in the same frame as the sentinel:** at 1280×800 the empty sentinel sits on the checkbox, so scrolling the end into view also unlocks Agree. The before/after pair is the honest demo.
- **`body_digest` UI:** none. SHA-256 is stored on `recording_studio_terms_and_conditions_acceptances.body_digest` at `accept!` time. Do not invent a digest column on Users.

Copies also live under `/opt/cursor/artifacts/tnc-pr3/`.

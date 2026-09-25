---
name: recording-studio-terms-and-conditions
description: Published Terms, clickwrap acceptance, and the host gate for Recording Studio apps. Use when a host needs people to accept the current published Terms before using a workspace, or when tempted to hand-roll acceptances.
---

# Recording Studio Terms and Conditions

This is the kit gem for **published Terms** and **clickwrap acceptance**. Do not invent a second acceptance table, accept screen, or post-auth redirect.

Repo: [RecordingStudio_terms_and_conditions](https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions). Rubygems name: `recording_studio_terms_and_conditions`. Current version: **0.7.4**.

## Need

| Need | Gem |
|---|---|
| Current published Terms + clickwrap + re-gate on a new publish | [`recording_studio_terms_and_conditions`](https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions) |

Add this row to the approved kit in `recording-studio-gems` (Platform). Do not hand-roll Terms.

## Install

```bash
# Gemfile
gem "recording_studio_terms_and_conditions", github: "bowerbird-app/RecordingStudio_terms_and_conditions"
```

```bash
bundle install
bin/rails generate recording_studio_terms_and_conditions:install
bin/rails db:migrate
```

The install generator mounts the engine, copies migrations, and writes the initializer. Then:

- Register `RecordingStudioTermsAndConditions::Terms` in `recordable_types`.
- Mount Publishable at `/` for `/terms/:uuid/:slug`.
- Mount Admin, add an `AdminRoot`, enable `section :terms`, grant Accessible on that root. The Terms hub does not show **+ Access**. Writes use the registered Admin `terms` resource; switch to the Admin root before opening engine write URLs.
- Publish with Publishable `QuickActions` on term show, or the Publish settings hub. Preview is `/recordings/:id/publishable/preview`.

## Domain

```ruby
terms = RecordingStudioTermsAndConditions.current_published_for(workspace)
privacy = RecordingStudioTermsAndConditions.current_published_for(workspace, kind: "privacy_policy")
RecordingStudioTermsAndConditions.pending_published_list(user, workspace)
RecordingStudioTermsAndConditions.requires_acceptance?(user, workspace)
RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "clickwrap" })
RecordingStudioTermsAndConditions.accepted?(user, workspace)
```

Live means Publishable `currently_published?`. `kind` is `terms_and_condition` or `privacy_policy` — one lineage per kind per workspace. Admin New is blocked when that kind already exists; versions come from edit/fork. SoleLive drafts other live rows of the same kind only. `accept!` raises `NotLive` for drafts and unpublished versions. Retrying the same actor and live snapshot returns the existing receipt. Saving live Terms forks a draft; the published copy stays live. Publishing the draft drafts the previous live version of that kind. A later published version still inserts a new receipt. Acceptance rows are receipts, not recordings. New receipts store `body_digest` (read via `receipt_contract`).

`pending_published_list` is the live Terms and/or Privacy Policy the actor still needs (0..2). The host gate (`ForcesAcceptance`) and Users Auth post-auth stay on until that set is empty.

When Users `>= 0.12.1` is loaded, this gem overrides `recording_studio_user/auth/registrations/_extra_fields` on create-password signup. Pending live Terms render `recording_studio_terms_continue_notice`. After a successful `create_password`, `accept!` runs with `{ "source" => "continue_notice" }`. Continuing the form is the agreement. The gem still boots if Users Auth is absent.

Drop the host helper onto a form:

```erb
<%= recording_studio_terms_agree %>
<%= recording_studio_terms_agree(inside_form: true) %>
<%= recording_studio_terms_agree(link_terms: true) %>
<%= recording_studio_terms_continue_notice %>
<%= recording_studio_terms_continue_notice(size: :sm) %>
<%= recording_studio_terms_continue_notice(link: false) %>
```

The checkbox helper is HTML `required`, named `agreed`. It wraps in `mt-3 mb-6` so there is a comfortable gap before the host button. Put it in a form. Prefer `recording_studio_terms_agree_button` (Flatpack `style: :primary`) for Agree / Accept. On submit call `accept!` for the pending live version. Do not add a second receipt table.

`recording_studio_terms_continue_notice` is a second helper. Copy uses `config.app_name`. Default is `text-xs` plus muted Flatpack copy (`text-[var(--surface-muted-content-color)]`). `size:` is `:xs` (default) or `:sm`. Unknown sizes use `:xs`. The Terms & Conditions words are a Flatpack Link (primary + underline). They open a Flatpack Modal whose body is the standalone terms document (`published_terms/_document`: PageTitle, date, Flatpack Content). When a Privacy Policy is also pending, the sentence includes “and privacy policy” and a second modal. `link:` defaults to `true`. Pass `link: false` for the same sentence as plain text, with no link and no modal. Accept passes `link: false`. Each live document is a full-width secondary **View {name}** button that opens `continue_notice_modal`. Signup keeps the link. Agree checkbox copy includes “and privacy policy” when privacy is pending; the privacy link uses `target=_blank`. Terms links stay same-tab. On that host POST, call `accept!` for each pending live version with `{ "source" => "continue_notice" }` (or `clickwrap`). Do not remove the checkbox helper. Dummy `/agree_helper` posts both helpers and then lets home load.

The gem Agree screen does not apply scroll-to-end. Hosts that still want a scroll gate wrap their own copy:

```ruby
RecordingStudioTermsAndConditions.configure do |config|
  config.require_scroll_to_end = true
end
```

Or wrap a host clickwrap with `recording_studio_terms_scroll_to_end(require_scroll_to_end: true)` and `recording_studio_terms_agree_button(require_scroll_to_end: true)`. Pin `recording_studio_terms_and_conditions/controllers` in the host importmap. The checkbox is still required. Missing IntersectionObserver leaves Agree enabled.

Set `config.capture_request_provenance = true` only if the gem Agree screen should store IP and user agent (default off). Product config is `mount_path`, `app_name`, `require_scroll_to_end`, and `capture_request_provenance`. There is no API key.

Agree is still the post-auth destination. It has no PageNav. The page is a narrow column. Each pending document is a full-width secondary **View {name}** button that opens the same continue-notice modal. Accept PageTitle follows the pending set: terms only, privacy only, or “We have updated our terms and conditions and privacy policy.” when both are pending. No on-page re-accept Alert, and the gate does not flash. Continue-notice (`link: false` on Accept) and **Continue** stay at the bottom (no checkbox). Agreeing again to the same live copy keeps the original receipt time. The notice wrapper is `mt-3 mb-3` on Accept and create-password. Signup continue-notice uses `root_for_signup`, which falls back when the current root has no live Terms.

## Upgrade (0.7.3 → 0.7.4)

No migrations. Admin hub actions are the live Terms page, the live Privacy Policy page, **Edit Terms**, and **Edit Privacy Policy**, all secondary. Hub cards are **Terms and conditions** and **Privacy Policy** (large count, smaller **users agreed**). The versions screen is the table only (live first). The engine terms index redirects there. Who agreed searches name or email. Agree is `/recording_studio_terms_and_conditions/acceptance`. The engine root redirects there. Public Terms stay on `/terms/:uuid/:slug`. Agree is a narrow column. Each live document is a full-width secondary **View {name}** button that opens the continue-notice modal. Continue and the “By continuing…” line stay on the page after someone has already agreed. A second continue does not change the receipt time.

## Upgrade (0.7.2 → 0.7.3)

No migrations. Checkbox helper wraps in `mt-3 mb-6` (was `my-3`). Prefer `recording_studio_terms_agree_button` or Flatpack Button `style: :primary` for the CTA under the checkbox.

## Upgrade (0.7.1 → 0.7.2)

No migrations. Pin `recording_studio_user` `>= 0.12.2` (GitHub tag `v0.12.2`). Auth layout loads `flat_pack/application`, so Sign in and Sign up primary buttons fill.

## Upgrade (0.7.0 → 0.7.1)

No migrations. Continue-notice wraps in `mt-3 mb-3` (was `mt-3 mb-6`). Accept and create-password share that helper.

## Upgrade (0.6.6 → 0.7.0)

Run the migrations generator and migrate. Existing Terms default to `terms_and_condition`. Add a Privacy Policy from Admin New when that kind is still free. Public privacy pages are `/privacy/:uuid/:slug`. Gate pending and Accept cover both kinds. Continue-notice and Agree checkbox mention privacy when pending.

## Upgrade (0.6.5 → 0.6.6)

No migrations. The gate no longer flashes “We've updated our Terms and Conditions”. Accept still uses the page title “We have updated our terms and conditions.”

## Upgrade (0.6.4 → 0.6.5)

No migrations. Pin FlatPack `>= 0.1.196` (dummy tag `v0.1.196`) and rebuild Tailwind. Continue-notice still links “Terms & Conditions” and opens the modal. Pass `link: false` for plain text with no modal. Accept does that. Signup keeps the link. Accept PageTitle is “We have updated our terms and conditions.” The Collapse title stays the Terms name.

## Upgrade (0.6.3 → 0.6.4)

No migrations. Accept **Continue** stays Flatpack `style: :primary`. The engine appends `flat_pack/application` so primary paint works when a host only loaded `flat_pack/variables`. Prefer linking `flat_pack/application` from `_default_layout_head` with Tailwind last. Re-gate Accept PageTitle is “We have updated our terms and conditions.”

## Upgrade (0.6.2 → 0.6.3)

No migrations. `root_for_signup` falls back when the current root has no live Terms. Agree drops the on-page “Terms updated” Alert; re-accept flashes “We've updated our Terms and Conditions”. Accept screen uses continue-notice + **Continue** (no checkbox). Pin FlatPack `>= 0.1.195`. Hosts that overrode `acceptances/show` only for the old Alert or checkbox can delete the override.

## Upgrade (0.6.1 → 0.6.2)

No migrations. The gem Agree screen no longer applies scroll-to-end. Dummy leaves `require_scroll_to_end` off. Hosts that still want a scroll gate wrap their own copy with the helper. First-time gate no longer flashes “One more thing — agree to the terms.” Successful Agree no longer flashes “You're in. Thanks for reading.”

## Upgrade (0.6.0 → 0.6.1)

No migrations. Pin `recording_studio_user` `>= 0.12.1`. Signup extra_fields is the continue-notice helper, not the checkbox. Receipts from that POST use provenance `continue_notice`. Continue-notice is xs and muted by default; pass `size: :sm` for the larger size. The Terms link opens a modal with the standalone terms document.

## Upgrade (0.3.x → 0.4.0)

```bash
bin/rails generate recording_studio_terms_and_conditions:migrations
bin/rails db:migrate
```

Run `body_digest` and unique actor+snapshot. Do not backfill old receipts. Delete `config.api_key`, `config.enable_feature_x`, `config.timeout`, and `RECORDING_STUDIO_TERMS_AND_CONDITIONS_API_KEY`. Drop preview `category` / `kind` / `change_note` columns if they exist.

`accept!` must be a live version (`NotLive` otherwise). Details: repo `CHANGELOG.md` and `MIGRATION_NOTES.md`.

## Upgrade (0.4.0 → 0.4.1)

No migrations. The Admin Terms hub no longer shows Accessible **+ Access**. Use the Accessible mount to grant access. Pin FlatPack `>= 0.1.186`. Engine admin writes go through the Admin `terms` resource and need the Admin root.

## Upgrade (0.4.x → 0.5.0)

Pin `recording_studio_publishable` `v0.3.1`. No Terms migrations. Term show uses `QuickActions` instead of a **Publish** button to the old edit form. Preview is not a query param on the public URL. Edit of live Terms forks a draft; publish when the new copy should go live.

## Upgrade (0.5.0 → 0.6.0)

No migrations. Set `config.app_name` for a fixed product name. A blank value uses `RecordingStudioSiteSettings.name_for` when that method exists. Continue-notice hosts render `recording_studio_terms_continue_notice` and call `accept!` with `continue_notice`. Agree skips PageNav (`skip_page_nav`).

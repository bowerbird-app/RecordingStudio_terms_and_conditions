---
name: recording-studio-terms-and-conditions
description: Published Terms, clickwrap acceptance, and the host gate for Recording Studio apps. Use when a host needs people to accept the current published Terms before using a workspace, or when tempted to hand-roll acceptances.
---

# Recording Studio Terms and Conditions

This is the kit gem for **published Terms** and **clickwrap acceptance**. Do not invent a second acceptance table, accept screen, or post-auth redirect.

Repo: [RecordingStudio_terms_and_conditions](https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions). Rubygems name: `recording_studio_terms_and_conditions`. Current version: **0.6.0**.

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
RecordingStudioTermsAndConditions.pending_published_list(user, workspace)
RecordingStudioTermsAndConditions.requires_acceptance?(user, workspace)
RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "clickwrap" })
RecordingStudioTermsAndConditions.accepted?(user, workspace)
```

Live means Publishable `currently_published?`. `accept!` raises `NotLive` for drafts and unpublished versions. Retrying the same actor and live snapshot returns the existing receipt. Saving live Terms forks a draft; the published copy stays live. Publishing the draft drafts the previous live version. A later published version still inserts a new receipt. The “You already agreed” Alert shows when the person has a receipt for older Terms in that workspace and the live snapshot is a different row. First-time Agree does not show it. Acceptance rows are receipts, not recordings. New receipts store `body_digest` (read via `receipt_contract`).

`pending_published_list` is the live Terms the actor still needs. The host gate (`ForcesAcceptance`) and Users Auth post-auth stay on until that set is empty.

Drop the host helper onto a form:

```erb
<%= recording_studio_terms_agree %>
<%= recording_studio_terms_agree(inside_form: true) %>
<%= recording_studio_terms_agree(link_terms: true) %>
<%= recording_studio_terms_continue_notice %>
```

The checkbox helper is HTML `required`, named `agreed`. Put it in a form. On submit call `accept!` for the pending live version. Do not add a second receipt table.

`recording_studio_terms_continue_notice` is a second helper. Copy uses `config.app_name`. The Terms & Conditions link opens a Flatpack Modal with `FlatPack::Content` inside. On that host POST, call `accept!` with `{ "source" => "continue_notice" }`. Do not remove the checkbox helper. Dummy `/agree_helper` posts both helpers and then lets home load.

Optional scroll-to-end before Agree (default off):

```ruby
RecordingStudioTermsAndConditions.configure do |config|
  config.require_scroll_to_end = true
end
```

Or wrap a host clickwrap with `recording_studio_terms_scroll_to_end(require_scroll_to_end: true)` and `recording_studio_terms_agree_button(require_scroll_to_end: true)`. Pin `recording_studio_terms_and_conditions/controllers` in the host importmap. The checkbox is still required. Missing IntersectionObserver leaves Agree enabled.

Set `config.capture_request_provenance = true` only if the gem Agree screen should store IP and user agent (default off). Product config is `mount_path`, `app_name`, `require_scroll_to_end`, and `capture_request_provenance`. There is no API key.

Agree is still the post-auth destination. It has no PageNav. Live copy sits in a closed Flatpack Collapse wrapping Content. The Collapse title is the live Terms heading (`terms_agree_heading`). Re-accept Alert stays above. Checkbox and Agree stay at the bottom.

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

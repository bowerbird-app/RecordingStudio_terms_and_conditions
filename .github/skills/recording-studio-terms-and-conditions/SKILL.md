---
name: recording-studio-terms-and-conditions
description: Published Terms, clickwrap acceptance, and the host gate for Recording Studio apps. Use when a host needs people to accept the current published Terms before using a workspace, or when tempted to hand-roll acceptances.
---

# Recording Studio Terms and Conditions

This is the kit gem for **published Terms** and **clickwrap acceptance**. Do not invent a second acceptance table, accept screen, or post-auth redirect.

Repo: [RecordingStudio_terms_and_conditions](https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions). Rubygems name: `recording_studio_terms_and_conditions`. Current version: **0.4.0**.

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
- Mount Admin, add an `AdminRoot`, enable `section :terms`, grant Accessible on that root.
- Publish through Publishable's edit UI.

## Domain

```ruby
terms = RecordingStudioTermsAndConditions.current_published_for(workspace)
RecordingStudioTermsAndConditions.current_published_by_category(workspace)
RecordingStudioTermsAndConditions.pending_published_list(user, workspace)
RecordingStudioTermsAndConditions.requires_acceptance?(user, workspace)
RecordingStudioTermsAndConditions.requires_acceptance?(user, workspace, required_categories: %w[terms])
RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "clickwrap" })
RecordingStudioTermsAndConditions.accepted?(user, workspace)
RecordingStudioTermsAndConditions.current_published_for(workspace, category: "privacy")
```

Live means Publishable `currently_published?`. `accept!` raises `NotLive` for drafts and unpublished versions. Retrying the same actor and live snapshot returns the existing receipt. A later published revision still inserts a new row. The “You already agreed” Alert shows when the person has a receipt for an older snapshot of that Terms recording and the live snapshot is a different row. First-time Agree does not show it. Optional `change_note` is extra copy, not the trigger. Acceptance rows are receipts, not recordings. New receipts store `body_digest` (read via `receipt_contract`).

`category` on Terms is `terms`, `privacy`, or `usage` — one recording per category per workspace, still `::Terms`. `current_published_for` and `accepted?` default to `terms`. `requires_acceptance?` covers every published category unless you pass `category:` or `required_categories:` (or `config.required_categories`). `pending_published_list` is the pending live set the Agree screen shows. One checkbox covers that set; the Agree POST calls `accept!` for each. The host gate (`ForcesAcceptance`) and Users Auth post-auth stay on until that set is empty. Admin Terms filter with `category=` and show coverage per category.

Drop the host helper onto a form:

```erb
<%= recording_studio_terms_agree %>
<%= recording_studio_terms_agree(inside_form: true) %>
<%= recording_studio_terms_agree(link_terms: true) %>
```

The helper is the checkbox only — HTML `required`, named `agreed`. Put it in a form. On submit call `accept!` for each pending live version from `pending_published_list`. Do not add a second receipt table.

Optional scroll-to-end before Agree (default off):

```ruby
RecordingStudioTermsAndConditions.configure do |config|
  config.require_scroll_to_end = true
end
```

Or wrap a host clickwrap with `recording_studio_terms_scroll_to_end(require_scroll_to_end: true)` and `recording_studio_terms_agree_button(require_scroll_to_end: true)`. Pin `recording_studio_terms_and_conditions/controllers` in the host importmap. The checkbox is still required. Missing IntersectionObserver leaves Agree enabled.

Set `config.capture_request_provenance = true` only if the gem Agree screen should store IP and user agent (default off). Product config is `mount_path`, `require_scroll_to_end`, `capture_request_provenance`, and optional `required_categories`. There is no API key.

## Upgrade (0.3.x → 0.4.0)

```bash
bin/rails generate recording_studio_terms_and_conditions:migrations
bin/rails db:migrate
```

Run `body_digest`, unique actor+snapshot, `change_note`, and `category`. Do not backfill old receipts. Delete `config.api_key`, `config.enable_feature_x`, `config.timeout`, and `RECORDING_STUDIO_TERMS_AND_CONDITIONS_API_KEY`.

Publishing privacy or usage now gates that category unless you narrow with `required_categories`. `accept!` must be a live version (`NotLive` otherwise). Host forms that ticked one document should call `accept!` for each item in `pending_published_list`. Details: repo `CHANGELOG.md` and `MIGRATION_NOTES.md`.

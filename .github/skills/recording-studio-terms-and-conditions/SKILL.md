---
name: recording-studio-terms-and-conditions
description: Published Terms, clickwrap acceptance, and the host gate for Recording Studio apps. Use when a host needs people to accept the current published Terms before using a workspace, or when tempted to hand-roll acceptances.
---

# Recording Studio Terms and Conditions

This is the kit gem for **published Terms** and **clickwrap acceptance**. Do not invent a second acceptance table, accept screen, or post-auth redirect.

Repo: [RecordingStudio_terms_and_conditions](https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions). Rubygems name: `recording_studio_terms_and_conditions`.

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
RecordingStudioTermsAndConditions.requires_acceptance?(user, workspace)
RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "clickwrap" })
RecordingStudioTermsAndConditions.accepted?(user, workspace)
```

Live means Publishable `currently_published?`. Acceptance rows are receipts, not recordings.

The gem includes `ForcesAcceptance` on the host `ApplicationController` and prepends Users Auth after sign in / sign up to the same Agree screen.

Drop the host helper onto a form:

```erb
<%= recording_studio_terms_agree %>
<%= recording_studio_terms_agree(inside_form: true) %>
<%= recording_studio_terms_agree(link_terms: true) %>
```

The helper is the checkbox only — HTML `required`, named `agreed`. Put it in a form. On submit call `accept!` with `params[:agreed]`. Do not add a second receipt table.

Optional scroll-to-end before Agree (default off):

```ruby
RecordingStudioTermsAndConditions.configure do |config|
  config.require_scroll_to_end = true
end
```

Or wrap a host clickwrap with `recording_studio_terms_scroll_to_end(require_scroll_to_end: true)` and `recording_studio_terms_agree_button(require_scroll_to_end: true)`. Pin `recording_studio_terms_and_conditions/controllers` in the host importmap. The checkbox is still required. Missing IntersectionObserver leaves Agree enabled.

`accept!` stores a SHA-256 digest of the live Terms body on the Acceptance row (`body_digest`). Read it via `receipt_contract`. Old receipts are not rewritten. Retrying `accept!` for the same actor and snapshot returns the existing receipt. A later published revision still inserts a new row. Set `config.capture_request_provenance = true` only if the gem Agree screen should store IP and user agent (default off).

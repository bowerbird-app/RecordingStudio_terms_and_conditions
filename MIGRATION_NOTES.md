# Migration Notes

## Host install

```bash
bin/rails generate recording_studio_terms_and_conditions:install
bin/rails db:migrate
```

That copies Terms and Acceptance migrations, mounts the engine, writes `config/initializers/recording_studio_terms_and_conditions.rb`, and pins the scroll-to-end Stimulus controller when `config/importmap.rb` exists.

Then:

- Register `RecordingStudioTermsAndConditions::Terms` in `recordable_types`.
- Mount Publishable at `/`.
- Enable Admin `section :terms` on an Admin root and grant Accessible access.
- Publish with Publishable `QuickActions` on term show, or the Publish settings hub. Do not add a custom publish action.

The host gate and Users post-auth hook attach automatically. Users `>= 0.12.1` also gets the create-password continue-notice and `accept!` with provenance `continue_notice`.

## Upgrade from 0.7.1 to 0.7.2

No schema change. Pin `recording_studio_user` `>= 0.12.2` (dummy and root GitHub tag `v0.12.2`). Users auth layout loads `flat_pack/application`, so Sign in and Sign up primary buttons fill.

## Upgrade from 0.7.0 to 0.7.1

No schema change. `recording_studio_terms_continue_notice` wraps in `mt-3 mb-3` instead of `mt-3 mb-6`. Accept and create-password use that same helper, so the gap above **Continue** and **Sign up** tightens together.

## Upgrade from 0.6.6 to 0.7.0

```bash
bin/rails generate recording_studio_terms_and_conditions:migrations
bin/rails db:migrate
```

Adds `kind` on Terms (`terms_and_condition` default, or `privacy_policy`). One lineage per kind per workspace. Admin New is blocked when that kind already exists; edit a live copy to fork the next draft. SoleLive drafts other live rows of the same kind only. Gate pending is 0..2. Accept and host helpers write one receipt per pending live version. Accept PageTitle and Collapse rows follow the pending kinds. Public privacy pages are `/privacy/:uuid/:slug`. Continue-notice wraps with spacing; pass `link: false` for plain text. Agree checkbox mentions privacy when a privacy document is pending; privacy links open in a new tab.

## Upgrade from 0.6.5 to 0.6.6

No schema change. The gate no longer flashes “We've updated our Terms and Conditions” when a new live version needs another yes. Accept still uses the page title “We have updated our terms and conditions.”

## Upgrade from 0.6.4 to 0.6.5

No schema change. Pin FlatPack `>= 0.1.196` and rebuild Tailwind. `recording_studio_terms_continue_notice` still links “Terms & Conditions” and opens the modal. Pass `link: false` for plain text with no modal. Accept already does that because the Collapse shows the terms. Signup keeps the link. Accept PageTitle is “We have updated our terms and conditions.” on a first visit and a re-gate. The Collapse title stays the Terms name.

## Upgrade from 0.6.3 to 0.6.4

No schema change. Accept **Continue** is already Flatpack primary (`data-fp-style="primary"`). The engine appends `flat_pack/application` so the filled CTA paints when the host only linked `flat_pack/variables`. Still load `flat_pack/application` from `_default_layout_head` and keep Tailwind last. Re-gate Accept PageTitle is “We have updated our terms and conditions.” Flash stays “We've updated our Terms and Conditions”.

## Upgrade from 0.6.2 to 0.6.3

No schema change. `root_for_signup` falls back when the current root has no live Terms. Agree drops the on-page “Terms updated” Alert; re-accept flashes “We've updated our Terms and Conditions”. Accept screen uses continue-notice + **Continue** (no checkbox); POST writes `continue_notice`. Pin FlatPack `>= 0.1.195` and rebuild Tailwind. Hosts that overrode `acceptances/show` only for the old Alert or checkbox can delete the override after bumping.

## Upgrade from 0.6.1 to 0.6.2

No schema change. The gem Agree screen no longer applies `require_scroll_to_end`. Dummy leaves it off. Hosts that still want a scroll gate wrap their own live copy with `recording_studio_terms_scroll_to_end` and `recording_studio_terms_agree_button`. First-time redirects to Agree no longer flash “One more thing — agree to the terms.” Successful Agree no longer flashes “You're in. Thanks for reading.”

## Upgrade from 0.6.0 to 0.6.1

No schema change. Pin `recording_studio_user` `>= 0.12.1`. Signup extra_fields is the continue-notice helper. A successful create-password writes `{ "source" => "continue_notice" }`. Keep `ForcesAcceptance` and `UsersAuthRedirect`. Continue-notice is xs and muted by default; pass `size: :sm` for the larger size. The Terms link opens a modal with the standalone terms document.

## Upgrade from 0.5.0 to 0.6.0

No schema change. Set `config.app_name` for a fixed product name. Leave it blank to use `RecordingStudioSiteSettings.name_for` when Site Settings is loaded.

`recording_studio_terms_continue_notice` is a second helper. Host POST for that path calls `accept!` with `{ "source" => "continue_notice" }`. The checkbox helper stays.

Agree no longer calls `terms_page_nav`. Dummy default layout skips PageNav when `skip_page_nav` is set. Live copy is a closed Flatpack Collapse plus Content. Optional scroll-to-end is unchanged.

## Upgrade from 0.4.x to 0.5.0

Pin `recording_studio_publishable` `v0.3.1`. No Terms or Acceptance schema change.

Term show uses Publishable `QuickActions` instead of a **Publish** button to the old edit form. Preview is `/recordings/:id/publishable/preview`. Public templates can render `publishable_preview_badge`. Hosts that overrode the Publishable edit form should switch to the hub plus Schedule / SEO / Social.

Editing live Terms forks a draft. The published copy stays live until that draft is published. Do not `revise` a live Terms recording to change the public wording.

## Upgrade from 0.4.0 to 0.4.1

No schema change. The Admin Terms hub no longer renders Accessible **+ Access**. Open the Accessible mount to grant or edit access.

Pin FlatPack `>= 0.1.186` and rebuild Tailwind. Live Terms copy uses `FlatPack::Content` (`fp-content`). Dummy sample title is **Terms and Conditions v1.0**.

Engine admin screens authorize through the Admin `terms` resource. With Root Switchable, use the Admin root; a workspace root is forbidden. New and Edit need Accessible `:edit`.

## Upgrade from 0.3.x to 0.4.0

```bash
bin/rails generate recording_studio_terms_and_conditions:migrations
bin/rails db:migrate
```

Hosts already on 0.3 pick up:

| Migration | What it does |
| --- | --- |
| `body_digest` on acceptances | SHA-256 of the live body at `accept!`. Do not backfill old rows. |
| Unique actor + recording + snapshot | Idempotent `accept!`. Drops `index_rstac_acceptances_on_actor_and_version` only if that name exists, then adds it unique. Resolve duplicate actor+snapshot rows before migrating. Do not rewrite those rows. New installs get the unique index from create. |
| Drop `category` / `kind` / `change_note` on Terms | Only if a 0.4.0 preview added them. Hosts coming from 0.3 skip those columns. |

Delete `config.api_key`, `config.enable_feature_x`, `config.timeout`, and `RECORDING_STUDIO_TERMS_AND_CONDITIONS_API_KEY`. Unknown keys are ignored. Drop `config.required_categories` if you copied a preview initializer.

Product config after 0.4.0 is `mount_path`, `require_scroll_to_end` (default off), and `capture_request_provenance` (default off).

## Behavior in 0.4.0

- Live means Publishable `currently_published?`. `accept!` raises `RecordingStudioTermsAndConditions::NotLive` for drafts, unpublished, and scheduled-but-not-live versions and does not write a receipt.
- Retrying `accept!` for the same actor and snapshot returns the existing receipt. A later published revision still needs a new tick. Callers cannot pass a spoofed digest in provenance.
- `pending_published_list` is the live Terms the actor still needs (zero or one). The gem Agree screen and host gate stay on until that set is empty.
- Scroll-to-end stays off until `config.require_scroll_to_end = true` (or the helper option). Missing IntersectionObserver leaves Agree enabled. An already-visible sentinel unlocks immediately.

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.2.0`)
- Accessible dummy tag `v0.9.1` and Root Switchable dummy tag `v0.5.0`
- FlatPack dummy tag `v0.1.186`
- Publishable dummy tag `v0.3.1` (gemspec `~> 0.3`)
- Users `>= 0.12.1` (dummy GitHub tag `v0.12.1`)
- Public RubyGems and GitHub access for dependency installation

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.

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

The host gate and Users post-auth hook attach automatically.

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
| `change_note` on Terms | Optional. Shown on the re-gate Agree Alert. |
| `category` on Terms | Default `"terms"`. At most one Terms recording per category per workspace (`terms`, `privacy`, `usage`). |
| Rename `kind` → `category` | Only if an earlier 0.4.0 preview added `kind`. Hosts coming from 0.3 skip this. |

Delete `config.api_key`, `config.enable_feature_x`, `config.timeout`, and `RECORDING_STUDIO_TERMS_AND_CONDITIONS_API_KEY`. Unknown keys are ignored.

Product config after 0.4.0 is `mount_path`, `require_scroll_to_end` (default off), `capture_request_provenance` (default off), and optional `required_categories` (`nil` means every currently published category).

## Behavior in 0.4.0

- Live means Publishable `currently_published?`. `accept!` raises `RecordingStudioTermsAndConditions::NotLive` for drafts, unpublished, and scheduled-but-not-live versions and does not write a receipt.
- Retrying `accept!` for the same actor and snapshot returns the existing receipt. A later published revision still needs a new tick. Callers cannot pass a spoofed digest in provenance.
- `current_published_for` and `accepted?` still default to `category: "terms"`.
- `requires_acceptance?` with no narrowing is true if any published category still needs a tick. Pass `category:`, `required_categories:`, or `config.required_categories` to constrain the gate. A terms-only workspace matches 0.3.
- `pending_published_list` is the pending live set. The gem Agree screen lists that set behind one checkbox and calls `accept!` for each. The host gate and Users post-auth stay on until the set is empty.
- Admin Terms filter with `category=` and show coverage (live/draft/agrees) per category.
- Scroll-to-end stays off until `config.require_scroll_to_end = true` (or the helper option). Missing IntersectionObserver leaves Agree enabled. An already-visible sentinel unlocks immediately.

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.2.0`)
- Accessible dummy tag `v0.9.1` and Root Switchable dummy tag `v0.5.0`
- FlatPack dummy tag `v0.1.183`
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

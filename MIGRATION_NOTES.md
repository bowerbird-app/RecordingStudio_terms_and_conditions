# Migration Notes

## Host install

```bash
bin/rails generate recording_studio_terms_and_conditions:install
bin/rails db:migrate
```

That copies Terms and Acceptance migrations (including `body_digest` and a unique actor+snapshot index), mounts the engine, writes `config/initializers/recording_studio_terms_and_conditions.rb`, and pins the scroll-to-end Stimulus controller when `config/importmap.rb` exists. Register `RecordingStudioTermsAndConditions::Terms` in `recordable_types`. Mount Publishable at `/`. Enable Admin `section :terms` on an Admin root and grant Accessible access. The host gate and Users post-auth hook attach automatically. Scroll-to-end before Agree stays off until `config.require_scroll_to_end = true` (or the helper option). `capture_request_provenance` stays off unless you want IP and user agent on gem UI receipts. Do not backfill old acceptances. Retrying `accept!` for the same actor and snapshot reuses the existing receipt.

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

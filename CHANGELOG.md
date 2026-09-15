# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2026-09-15

### Added
- Optional `config.require_scroll_to_end` (default off) keeps Agree disabled until a Stimulus sentinel at the end of the live copy is visible.
- Admin term show puts receipts behind **Users** (left of Edit / Publish). The Who agreed table lives on that page, not under the copy.
- Engine Terms and Users tables paginate with Flatpack infinite pages (`Pagy`, 25 per page), same as Recording Studio Admin dummy tables. Admin `Terms` and `Who agreed` screens set `paginate per_page: 25`. Dummy `/docs/gem_views` uses the same page size.

### Changed
- `Admin.register!` reloads after Zeitwerk so the Terms hub survives a code reload. Term show prints Recording and snapshot ids.
- Admin hub Live terms and Agrees cards use `view_variant: :card` so the title sits above the number, not beside it. Admin screens that still force compact still render these widgets stacked, via `AdminWidgetCard`.

### Upgrade notes
- Scroll-to-end is off unless you set `config.require_scroll_to_end = true` or pass `require_scroll_to_end: true` to `recording_studio_terms_scroll_to_end` / `recording_studio_terms_agree_button`. Pin `recording_studio_terms_and_conditions/controllers` in the host importmap. The checkbox is still required.
- Receipts for a term are on **Users** (next to Edit / Publish), not under the copy on show. Terms, Users, and Admin hub tables load 25 rows at a time (infinite).

## [0.3.0] - 2026-09-14

### Added
- `RecordingStudioTermsAndConditions::Terms` recordable (table `recording_studio_terms_and_conditions_terms`, product label `"Terms"`). Publishable is opted in on the class with `RecordingStudio::Capabilities::Publishable.to`. Public `/terms/:uuid/:slug` is the Publishable page.
- `RecordingStudioTermsAndConditions::Acceptance` append-only table (`recording_studio_terms_and_conditions_acceptances`) for clickwrap receipts. Not a recordable.
- Domain helpers on `RecordingStudioTermsAndConditions`: `current_published_for(root)`, `accepted?(actor, root)`, `accept!(actor, version, provenance)`, `requires_acceptance?(actor, root)`. Live Terms use Publishable `currently_published?`. Acceptance rows store jsonb `provenance`.
- Clickwrap Accept UI (`AcceptancesController`) for the current published Terms. Checkbox starts unchecked; Agree is gated until it is ticked. Receipts call `accept!`.
- Admin Terms screens (create, edit, acceptance coverage) and a Publishable public page at `/terms/:uuid/:slug`. Admin registers a `terms` section. Dummy mounts Admin, Accessible, Publishable, and the engine.
- Host gate plus Users signup/post-auth hook: signed-in people who `requires_acceptance?` are sent to the existing Agree screen. A later published version gates them again.
- Install generator copies migrations, mounts the engine (skips if already mounted), and writes a host initializer. Kit skill `.github/skills/recording-studio-terms-and-conditions` names this gem for `recording-studio-gems`.

### Changed
- Agree, Admin Terms, and public `/terms/:uuid/:slug` use Recording Studio `recording_studio/default_layout` (PageNav + content column). Terms copy and write/edit sit on the page — no Card border wrapper. Agree checkbox keeps one label; the extra tick/agree help text is gone.
- Admin Terms index uses a Flatpack Table with Title / Status / Agrees / Open columns (hash rows, default table width). New and edit use Flatpack `TextArea` rich text (`rich_text: true`, content preset). Dummy seeds ship a multi-section sample body.
- Dummy default layout renders Flatpack `TopNav` for workspace switch and Sign out (`href` + `method: :delete`). PageNav only gets kwargs it accepts (`anchor_href`, not `back_url` / `anchor_url`). Dummy Tailwind also scans `/usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*` so table and nav utilities compile on Cloud Agent images.
- Host helper `recording_studio_terms_agree` (optional `inside_form: true`) mounts the required Agree checkbox. No helper button — put the box in a host form and call `accept!`. Dummy `/agree_helper` shows a code example plus the live checkbox.
- Dummy sign-in uses Recording Studio Users Auth (`recording_studio_user_auth_for :users`): email first, then password. The old Devise Login card is gone.
- Write Terms parks under Recording Studio Admin (`/admin`). Show pages put copy in the Flatpack content surface, print the calendar date (for example `13 Aug 2026`) tight under the subtitle, and give the Agree checkbox more vertical space. `recording_studio_terms_agree(link_terms: true)` turns the word terms into a link to the live public page. The helper does not add a second “Read the full terms” line — the Agree screen already shows the copy. Admin Terms tables include a Published column. Write/edit keep Title/Body spacing. The Body wrapper has no extra border; Save draft stays content-width.
- Product identity is `recording_studio_terms_and_conditions` / `RecordingStudioTermsAndConditions` (was the gem-template engine name).
- Homepage and source URLs point at https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions.
- README is the product guide. `docs/gem_template/` stays as engine internals.
- Hard kit dependencies: `recording_studio ~> 4.2`, `flat_pack >= 0.1.183`, `recording_studio_accessible ~> 0.8`, `recording_studio_admin ~> 2.0`, `recording_studio_publishable ~> 0.2`, `recording_studio_user ~> 0.11`. Dummy and root Gemfiles pin FlatPack `v0.1.183`.

### Upgrade notes
- Depend on `recording_studio_terms_and_conditions` instead of `gem_template`.
- Replace the previous engine module with `RecordingStudioTermsAndConditions` in require paths, mounts, and configuration.
- Point install/migrations generators at `recording_studio_terms_and_conditions:install` and `recording_studio_terms_and_conditions:migrations`. The install generator now copies migrations; you can still run the migrations generator on its own.
- Rename host files `config/initializers/gem_template.rb` and `config/gem_template.yml` to the new gem name.
- Bundle the new kit gems from GitHub (they are not on RubyGems). Register `RecordingStudioTermsAndConditions::Terms` (and Publishable's child type) in `config.recordable_types`.
- Run this gem's migrations generator, then Publishable's (and Users/Attachable if those engines load). Do not treat Acceptance rows as recordings.
- Call `RecordingStudioTermsAndConditions.current_published_for` / `accepted?` / `accept!` / `requires_acceptance?` instead of querying publishable children or inserting acceptance rows by hand.
- Mount this engine for the Agree screen. Mount Publishable at `/` so `/terms/:uuid/:slug` works. Mount Admin, add an `AdminRoot`, enable `section :terms`, and grant Accessible access to that root. Publish through Publishable's edit UI, not a custom publish action. Hosts should use `recording_studio/default_layout` (or `UsesDefaultLayout`) for those screens — drop any copied `recording_studio_terms_and_conditions/public` layout. Load `flat_pack/application` from `_default_layout_head` and keep Tailwind last.
- Expect the gem to include the acceptance gate on `ApplicationController` and to prepend the Users Auth redirect. Do not add a second clickwrap. After agree, people return to the page they asked for.
- Drop `recording_studio_terms_agree` or `recording_studio_terms_agree(inside_form: true)` onto host screens. Pass `link_terms: true` to turn the word terms into a link to the live public page. The helper is the required `agreed` checkbox only. Wrap it in your form, then call `accept!` with `params[:agreed]`. Do not add another receipt table. Standalone helper no longer posts or renders Agree.
- Open Write Terms from Recording Studio Admin (`/admin` when `root_section: :terms`). The engine write path is still there for the form.
- Dummy and hosts that still use a one-screen Devise login should mount Users Auth: skip Devise sessions/registrations/passwords, then `recording_studio_user_auth_for :users`.
- Add `recording_studio_terms_and_conditions` to the approved kit in `recording-studio-gems` (published Terms + clickwrap). Do not hand-roll acceptances.
- Point host and dummy Gemfiles at FlatPack `v0.1.183` (gemspec `>= 0.1.183`). Rebuild host Tailwind after adding `@source` for `/usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*` (install generator writes it). Flatpack `Button` takes `href`, not `url`. Flatpack `PageNav` takes `anchor_href`, not `back_url` / `anchor_url`.

## [0.2.2] - 2026-09-11

### Changed
- Gemspec `recording_studio` floor `~> 4.1` → `~> 4.2` so copied addons match Accessible 0.7+.
- Dummy Accessible tag `v0.6.0` → `v0.9.1`; FlatPack tag `v0.1.133` → `v0.1.177`. Recording Studio stays `v4.2.0`; Root Switchable stays `v0.5.0`.
- Root `Gemfile.lock` Rails `8.1.1` → `8.1.3.1` (with `json` `2.21.2`, `mail` `2.9.1`, `nokogiri` `1.19.4`) to match the dummy host lock and Active Storage CVE-2026-66066.
- Extra Cloud Agent skills now come from the plugin catalog (`skill-sources.json`) instead of a hardcoded extra URL. A missing or invalid catalog is skipped so Recording Studio skills still fetch. Failures still warn and exit 0.
- Docs and pin tests no longer mention `recording_studio/v3.0.0`, FlatPack `v0.1.133`, or Accessible `v0.6.0`.

### Added
- After skills, the Cloud Agent fetch hook lists plugin `*.mdc` rules from `RecordingStudio_cursor_plugin` into `.cursor/rules/` (gitignored, not packaged). A missing rules directory warns and skips. Failures still exit 0.
- Cloud Agent skill-fetch hook so copied addons load Recording Studio skills at Build time. `.cursor/environment.json` names the environment `recording-studio-gem-template`. `install` is `.cursor/install.sh`, which runs `.cursor/fetch-skills.sh` after provisioning. `snapshot` is omitted on purpose so Builds run install instead of reusing a laptop Personal snapshot. The script lists `recording-studio-*` skill ids from the public GitHub contents API and writes each `SKILL.md` into `.cursor/skills/` (gitignored, not packaged). Failures warn and still exit 0.
- Dummy Accessible migration for `depends_on_recording_id` (Accessible 0.8+).

### Upgrade notes
- Bump addon gemspecs to `spec.add_dependency "recording_studio", "~> 4.2"`.
- Point host/dummy Gemfiles at Accessible `v0.9.1` and FlatPack `v0.1.177` (Recording Studio tag stays `v4.2.0`).
- Run `bin/rails generate recording_studio_accessible:migrations` then `bin/rails db:migrate`. Do not hand-edit Accessible tables.
- Rebuild Tailwind after the FlatPack tag bump: `bin/rails tailwindcss:build`.
- Align root gem-suite `Gemfile.lock` Rails to `8.1.3.1` if it is still on `8.1.1`.

## [0.2.1] - 2026-09-01

### Added
- Full Cloud Agent development environment. `.cursor/install.sh` now provisions the whole stack at Build time on Cursor's default image — Ruby (pinned by `.ruby-version`), PostgreSQL 16, gem dependencies for both the gem and the dummy host app, the seeded dummy database, and compiled Tailwind/FlatPack CSS — then runs the existing `.cursor/fetch-skills.sh`. `snapshot` stays omitted so Builds run `install` as before.
- `.cursor/start.sh` per-boot hook that starts PostgreSQL and waits for readiness.
- `.cursor/environment.json` now declares `start` plus `rails-server` and `tailwind-watch` terminals and exposes port 3000, so a fresh Cloud Agent boots straight into a running, signed-in-ready dummy app.

### Notes
- The install script is idempotent; running it against a warm machine reuses the existing Ruby, packages, and gems.
- No gem runtime code changed. `.cursor/` files are excluded from the packaged gem.

## [0.2.0] - 2026-08-21

New addons copied from this template are born on Recording Studio 4.x.

### Added
- Gemspec dependency `recording_studio`, `~> 4.1`
- Dummy host wiring for Accessible (`enable_capability(:accessible, on: Workspace)`) and an opt-in `RecordingStudio::Capabilities::Example.to` mixin. `.to` wraps core 4.2.0 `include_for` (not a fourth verb, and not a raw `enable_capability` / `set_capability_options` path). Installing the gem does not enable the mixin globally; only dummy Workspace opts in.
- `bin/rename_gem` leftover-identity rewrite/verification for README, homepage, and changelog URLs that still say `RecordingStudioTermsAndConditions` or point at `bowerbird-app/recording_studio_terms_and_conditions`

### Changed
- Dummy GitHub tags: Recording Studio `v4.2.0`, Accessible `v0.6.0`, Root Switchable `v0.5.0`, FlatPack `v0.1.133`
- Dummy authenticated layout is Recording Studio's default layout plus FlatPack CSS/JS; Devise keeps its own sign-in layout
- Dummy app security pins: Rails `8.1.3.1`, `json` `2.21.2`, `mail` `2.9.1`, Brakeman `8.0.6`
- Require `RecordingStudio::Hooks` and `RecordingStudio::Services::BaseService` from core instead of shipping copies

### Removed
- Copied `lib/recording_studio_terms_and_conditions/hooks.rb` and `lib/recording_studio_terms_and_conditions/services/base_service.rb`
- Product-shipped `ExampleService`
- Custom `flat_pack_sidebar` authenticated shell

### Upgrade notes
- Point dummy or host Gemfiles at Recording Studio `v4.2.0` (not `recording_studio/v3.0.0`)
- Add `spec.add_dependency "recording_studio", "~> 4.1"` to addon gemspecs
- Include `RecordingStudio::UsesDefaultLayout` (or set `layout "recording_studio/default_layout"`) for authenticated screens
- Delete any copied Hooks or BaseService files and require the core classes
- Keep recordable declarations; they are required, not a v3-only concern
- If Accessible is bundled, call `RecordingStudio.enable_capability(:accessible, on: Workspace)` (or your root type)

## [0.1.2] - 2026-07-21

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.129`

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.3.0
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.2.0
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.1.0

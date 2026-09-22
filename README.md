# Recording Studio Terms and Conditions

A Recording Studio addon for terms and conditions.

- Rubygems: `recording_studio_terms_and_conditions`
- Module: `RecordingStudioTermsAndConditions`
- Source: [bowerbird-app/RecordingStudio_terms_and_conditions](https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions)

This addon ships the **data shape, domain helpers, clickwrap Agree screen, embeddable Agree helpers, admin Terms screens, a public published URL, and a host gate**. Signed-in people who still need to accept the current published Terms are sent to the same Agree screen. Recording Studio Users signup and post-auth use that path too. Hosts can drop `recording_studio_terms_agree` or `recording_studio_terms_continue_notice` onto a form.

## What's included

- **Recording Studio** 4.x gem pinned and configured
- **Recording Studio Users Auth** (email, then password) with a pre-seeded admin user
- **Workspace**, **Folder**, and **Page** recordables seeded into the dummy host app
- **Terms** recordable (`RecordingStudioTermsAndConditions::Terms`, product label `"Terms"`) with Publishable opted in on the type
- **Acceptance** append-only table for clickwrap receipts (not a recordable). New rows store a SHA-256 body digest of the live copy at accept time
- **Domain helpers** on `RecordingStudioTermsAndConditions`: `current_published_for`, `pending_published_list` / `pending_published_for`, `accepted?`, `accept!`, `requires_acceptance?`, `reaccepting?`
- **Agree screen** for the current published Terms (pre-checked checkbox, gated Agree, `accept!`). No PageNav. Live copy sits in a Flatpack Collapse (closed by default) wrapping `FlatPack::Content`. The gem Agree screen does not use `require_scroll_to_end`. The calendar date stays in the heading, not a relative “hours ago”
- **Host helper** `recording_studio_terms_agree` / `recording_studio_terms_agree(inside_form: true)` — Flatpack checkbox only, HTML `required`. Pass `link_terms: true` to turn the word terms into a link to the public URL. On submit, call `accept!` for the pending live version
- **Host helper** `recording_studio_terms_continue_notice` — “By continuing, you agree to [app name]'s Terms & Conditions”. Default size is `:xs` with muted Flatpack copy (`text-[var(--surface-muted-content-color)]`). Pass `size: :sm` for `text-sm`. The Terms & Conditions words are a Flatpack Link (primary + underline). They open a Flatpack Modal whose body is the standalone terms view (title, date, Flatpack Content). On the host POST, call `accept!` with `{ "source" => "continue_notice" }`. Do not replace the checkbox helper
- **Gate** on the host `ApplicationController`: redirects to Agree until the live version is accepted, and again after a new publish
- **Users hook** on `RecordingStudioUser::Auth::BaseController` so after sign in / sign up land on Agree when acceptance is still required
- **Users create-password slot** (`recording_studio_user/auth/registrations/_extra_fields`) renders `recording_studio_terms_continue_notice` when live Terms are pending. Successful `create_password` calls `accept!` with provenance `continue_notice`. Soft: TnC still boots without Users Auth.
- **Admin** create/edit Terms, Publishable `QuickActions` (Draft / Publish now / Preview), and a Users page of receipts for each term. Engine tables use `TablePage` (Pagy, 25 rows) and Flatpack infinite pagination. Admin hub Terms and Conditions and Agree stats tables set `paginate per_page: 25`. Live and Agrees widgets stack the title above the count (`view_variant: :card`). The hub does not show Accessible **+ Access**. Writes go through a registered Admin `terms` resource (`authorize_resource!` / `perform_recording_studio_admin_action!`)
- **Public Terms URL** at `/terms/:uuid/:slug` via Publishable
- **FlatPack** UI component library for all views
- **Dummy app** (`test/dummy/`) with a FlatPack sign-in screen, a home page on Recording Studio's default layout, mounted Recording Studio routes, and FlatPack's built-in rounded theme

Authenticated dummy pages use Recording Studio's shared default layout (`RecordingStudio::UsesDefaultLayout`) plus FlatPack CSS and JS. They do not add a host TopNav (no demo bar, workspace switcher, or Sign out). The Admin hub also omits Accessible **+ Access**. Sign-in uses Users Auth (`recording_studio_user/auth`). Dummy `/docs/*` pages stay in the dummy app as a host-app sandbox; they are not the product README.

## Quick start

### Cursor Cloud Agent (recommended)

A Cloud Agent boots this repo into a ready-to-use dev environment with no manual steps. The setup lives in `.cursor/`:

- `install.sh` provisions Ruby (pinned by `.ruby-version`), PostgreSQL 16, all gems, the seeded dummy database, and compiled CSS at build time, then fetches Recording Studio skills.
- `start.sh` starts PostgreSQL on every boot.
- `environment.json` runs the `rails-server` and `tailwind-watch` terminals and exposes port 3000.

Open port 3000 and sign in at `/users/sign_in`. No environment variables are required — the dummy app's `database.yml` defaults match the provisioned PostgreSQL cluster.

### GitHub Codespaces

1. Click **Code** → **Codespaces** → **Create codespace**
2. Wait for setup to complete
3. Run:
   ```bash
   cd test/dummy
   bin/rails db:setup
   bin/dev
   ```
4. Open port 3000 — you'll land on the dummy app home page and can sign in at `/users/sign_in`

The dummy app is a host-app validation surface for authentication, FlatPack rendering, Tailwind source scanning, and Recording Studio route wiring.

### Login credentials

| Field    | Value             |
|----------|-------------------|
| Email    | admin@admin.com   |
| Password | Password          |

Sign in at `/users/sign_in`: email first (**Continue with email**), then password.

### Useful routes

- `/` — dummy app home page
- `/users/sign_in` — Users Auth sign-in (email, then password)
- `/recording_studio_terms_and_conditions` — Agree (clickwrap) screen on the Recording Studio default layout
- `/admin` — Recording Studio Admin Terms and Conditions hub (`New` parks here)
- `/recording_studio_terms_and_conditions/admin/terms` — engine write/edit form (opened from Admin). Switch to the Admin root first. New Terms is titled **New Terms and Conditions**.
- `/terms/:uuid/:slug` — public published Terms
- `/recording_studio` — redirect to `/` while the mounted Recording Studio engine remains data/API-focused
- `/agree_helper` — dummy demo of the embeddable Agree helper (code example + checkbox)
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` — dummy-only starter pages

The home page in `test/dummy/app/views/home/index.html.erb` is a starting point for a minimal demo of the gem's primary behavior. Keep deeper explanations on the dummy docs pages, not in this README.

## Host install

```bash
# Gemfile
gem "recording_studio_terms_and_conditions", github: "bowerbird-app/RecordingStudio_terms_and_conditions"
```

```bash
bundle install
bin/rails generate recording_studio_terms_and_conditions:install
bin/rails db:migrate
bin/rails tailwindcss:build
```

`recording_studio_terms_and_conditions:install` mounts the engine, copies this gem's migrations, and writes the initializer. Then register `RecordingStudioTermsAndConditions::Terms` in `recordable_types`, mount Publishable at `/`, and enable Admin `section :terms` on an Admin root with Accessible access.

This is the kit gem for published Terms and clickwrap. Add it to the approved list in `recording-studio-gems`. Do not hand-roll acceptances.

## Upgrading from 0.3.x

Bump to **0.4.0**, copy migrations, migrate. Run `body_digest` and unique actor+snapshot. Do not backfill old receipts. Drop template knobs `api_key`, `enable_feature_x`, `timeout`. Host `accept!` must be a live version (`NotLive` otherwise). Full notes: `CHANGELOG.md` (0.4.0) and `MIGRATION_NOTES.md`.

## Upgrading from 0.4.0

Bump to **0.4.1**. No schema change. The Admin Terms hub no longer shows Accessible **+ Access**. Grant access from the Accessible mount.

## Upgrading from 0.4.x

Bump to **0.5.0** and pin Publishable `v0.3.1`. No Terms schema change. Term show uses the Publishable status dropdown instead of a **Publish** button to the old edit form. Preview is its own route. Saving live Terms forks a draft; the public copy stays until you publish. Full notes: `CHANGELOG.md` (0.5.0).

## Upgrading from 0.6.2

Bump to **0.6.3**. No schema change. Signup continue-notice uses `root_for_signup` fallback when the current workspace has no live Terms. Agree no longer shows an on-page “Terms updated” Alert; re-accept still flashes “Terms changed. Agree again.” Hosts that overrode `acceptances/show` only for that Alert can drop the override.

## Upgrading from 0.6.1

Bump to **0.6.2**. No schema change. The gem Agree screen no longer applies scroll-to-end. Dummy leaves `require_scroll_to_end` off. The checkbox is still required. Hosts that still want a scroll gate wrap their own copy with the helper. First-time gate no longer flashes “One more thing — agree to the terms.” Successful Agree no longer flashes “You're in. Thanks for reading.”

## Upgrading from 0.6.0

Bump to **0.6.1** and pin `recording_studio_user` `>= 0.12.1`. No schema change. Create-password shows the continue-notice in Users `extra_fields` when live Terms are pending. Submitting that form writes a `continue_notice` receipt. Leave `ForcesAcceptance` and `UsersAuthRedirect` in place.

## Upgrading from 0.5.0

Bump to **0.6.0**. Set `config.app_name` if you want a fixed product name. When it is blank, the gem uses `RecordingStudioSiteSettings.name_for` if that method exists. Site Settings is optional. No schema change. Continue-notice hosts render `recording_studio_terms_continue_notice` and call `accept!` with `continue_notice`. Agree no longer sets PageNav. Dummy default layout skips PageNav when `skip_page_nav` is set.

## Architecture

### Root recording pattern

The dummy host follows Recording Studio's root recording pattern:

- **Workspace** is the dummy content root. Users also registers shared **People**.
- **Folder** and **Page** demonstrate nested host recordables under the workspace root
- **Terms** is this gem's nested recordable under Workspace. Enable Publishable on the class with `RecordingStudio::Capabilities::Publishable.to` — installing the gem does not publish anything by itself. Staff publish from term show with `QuickActions` (or the Publish settings hub)
- **Acceptance** rows are receipts, not tree nodes: actor, terms recording id, terms snapshot id, timestamps, SHA-256 `body_digest`, provenance. Old receipts stay untouched. `Acceptance#receipt_contract` is the readable shape
- Hosts ask the module for the live published version and whether an actor still needs to accept:
  ```ruby
  terms = RecordingStudioTermsAndConditions.current_published_for(workspace)
  RecordingStudioTermsAndConditions.pending_published_list(user, workspace)
  RecordingStudioTermsAndConditions.requires_acceptance?(user, workspace)
  RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "clickwrap" })
  RecordingStudioTermsAndConditions.accepted?(user, workspace)
  ```
  Live means Publishable `currently_published?` (scheduled-in-the-future is not current). `accept!` raises `RecordingStudioTermsAndConditions::NotLive` for drafts and unpublished versions and does not write a receipt. `indexable` is SEO and is not used for clickwrap. Retrying `accept!` for the same actor and snapshot returns the existing receipt. Saving live Terms forks a draft; people who already agreed stay agreed until that draft is published. A new published version still needs a new tick. The “You already agreed” Alert shows when Agree lists live Terms the person has not accepted yet and they already have a receipt for an older Terms version in that workspace. First-time Agree never shows it.
- The gem includes `ForcesAcceptance` on the host `ApplicationController` and prepends `UsersAuthRedirect` on Users Auth. Both reuse `pending_published_list` / `requires_acceptance?` and the mounted Agree screen. Auth, Agree, Admin, public Terms, and root switch stay reachable so people can sign in, accept, publish, or switch workspace.
- With Users `>= 0.12.1`, the gem fills the create-password `extra_fields` slot with `recording_studio_terms_continue_notice` and accepts pending live Terms on that POST (`source` `continue_notice`). Continuing the form is the agreement. `root_for_signup` falls back to another root when the current workspace has no live Terms. `NotLive` does not fail signup.
- Hosts can render `recording_studio_terms_agree` or `recording_studio_terms_agree(inside_form: true)` inside signup or similar. The helper is the `required` `agreed` checkbox only. On the host POST, call `accept!` for the pending live version — do not invent a second receipt.
- Agree has no on-page re-accept Alert. A new live version still flashes “Terms changed. Agree again.” and shows **Agree again**.
- Hosts can also render `recording_studio_terms_continue_notice`. Default is xs and muted. Pass `size: :sm` for `text-sm`. The link opens a Flatpack Modal with the standalone terms view (same document as the public show). On that POST, call `accept!` with `{ "source" => "continue_notice" }`.
- The gem Agree screen does not apply scroll-to-end. Hosts that still want a scroll gate wrap their own copy with `recording_studio_terms_scroll_to_end(require_scroll_to_end: true)` and `recording_studio_terms_agree_button(require_scroll_to_end: true)`, and pin the engine Stimulus controller in the host importmap. The checkbox stays required either way. Missing IntersectionObserver leaves Agree enabled.
- Product configuration is `mount_path`, `app_name`, `require_scroll_to_end`, and `capture_request_provenance` (IP/UA on gem UI accepts, default off). There is no API key. `app_name` is optional. A blank value uses Site Settings `name_for` when that gem is loaded.
- Each configured recordable declares `recording_studio_recordable(...)`; strict declaration validation stays enabled
- A root `RecordingStudio::Recording` wraps the Workspace
- `Current.actor` is set from `current_user` (Devise) in `ApplicationController`

### Extending Recording Studio

To add new recordable types:

1. Create your model (e.g., `Page`, `Comment`)
2. Register it in `config/initializers/recording_studio.rb`:
   ```ruby
   RecordingStudio.configure do |config|
     config.recordable_types = ["Workspace", "YourNewType"]
   end
   ```
3. Declare whether the model can be a root and which parents may contain it:
   ```ruby
   class YourNewType < ApplicationRecord
     recording_studio_recordable label: "Your new type",
                                 root: false,
                                 allowed_parent_types: ["Workspace", "Folder"]
   end
   ```
4. Validate declarations and create recordings under the root:
   ```ruby
   RecordingStudio.validate_recordable_declarations!
   root_recording = RecordingStudio.root_recording_for(workspace)
   root_recording.record(YourNewType) do |record|
     record.title = "Example"
   end
   ```

### Recordable declarations

Every configured ActiveRecord recordable type must declare its hierarchy rules. Declarations are required; they are not version-specific.

- `Workspace` declares `root: true`
- `Folder` and `Page` declare `root: false, allowed_parent_types: ["Workspace", "Folder"]`
- `RecordingStudioTermsAndConditions::Terms` declares `label: "Terms"`, `root: false`, `allowed_parent_types: ["Workspace"]`
- Dummy also registers Users (`People`, `Profile`), Publishable, and Attachable types so those kit gems can boot
- `config.require_recordable_declarations = true` remains enabled in the dummy app initializer

Useful console checks:

```ruby
RecordingStudio.validate_recordable_declarations!
RecordingStudio.root_recordable_types
RecordingStudio.allowed_parent_types_for("Page")
```

### Capabilities

Capability mixins are opt-in. Installing this gem does not enable mixins on host types.

The dummy Workspace enables Accessible because that addon is bundled:

```ruby
RecordingStudio.enable_capability(:accessible, on: Workspace)
```

The dummy also ships one example mixin that uses core 4.2.0's `include_for` factory:

```ruby
include RecordingStudio::Capabilities::Example.to(label: "dummy workspace")
```

`.to` wraps `RecordingStudio::Capabilities.include_for`. It does not add a fourth verb and it does not call `enable_capability` / `set_capability_options` itself. Folder and Page stay without the example mixin.

Use core `RecordingStudio::Hooks` and `RecordingStudio::Services::BaseService`. Do not copy those classes into this addon.

### FlatPack UI components

All views use FlatPack ViewComponents. Available components include:

- `FlatPack::Button::Component` — Buttons (`:primary`, `:secondary`, `:ghost`)
- `FlatPack::Card::Component` — Cards (`:default`, `:elevated`, `:outlined`)
- `FlatPack::Alert::Component` — Alerts (`:success`, `:error`, `:warning`, `:info`)
- `FlatPack::Badge::Component` — Status badges
- `FlatPack::Table::Component` — Data tables
- `FlatPack::TextInput::Component`, `EmailInput`, `PasswordInput` — Form inputs
- `FlatPack::PageNav::Component` — Default-layout page navigation
- `FlatPack::PageTitle::Component` — Page titles

Use the live FlatPack demo app at [flatpack.bowerbird.io](https://flatpack.bowerbird.io/) as the approved UI reference for current shared patterns. Its component table is the fastest way to discover available FlatPack components before introducing new custom UI.

See the [FlatPack README](https://github.com/bowerbird-app/flatpack) for full documentation.

## Tech stack

| Component       | Version |
|-----------------|---------|
| Ruby            | 3.3+    |
| Rails           | 8.1+    |
| PostgreSQL      | 16      |
| TailwindCSS     | 4       |
| RecordingStudio | 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.2.0`) |
| Accessible      | gemspec `~> 0.8`; dummy GitHub tag `v0.9.1` |
| Admin           | gemspec `~> 2.0`; dummy GitHub tag `v2.0.2` |
| Users           | gemspec `recording_studio_user >= 0.12.1`; dummy GitHub tag `v0.12.1` |
| Publishable     | gemspec `~> 0.3`; dummy GitHub tag `v0.3.1` |
| Attachable      | dummy GitHub tag `v0.5.1` (Users Profile needs it) |
| Root Switchable | dummy GitHub tag `v0.5.0` |
| FlatPack        | gemspec `>= 0.1.186`; dummy GitHub tag `v0.1.186` |
| Devise          | latest  |

The dummy Gemfile keeps `github:` sources so Bundler can fetch those gems. Hosts also need Publishable (and Users/Attachable) migrations from those gems — this addon only ships Terms and Acceptance migrations.

## Documentation

Engine internals from the original gem template stay in `docs/gem_template/` as architectural reference. This README, `CHANGELOG.md`, `MIGRATION_NOTES.md`, and the dummy app are the source of truth for the addon.

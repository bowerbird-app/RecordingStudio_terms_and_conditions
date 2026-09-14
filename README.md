# Recording Studio Terms and Conditions

A Recording Studio addon for terms and conditions.

- Rubygems: `recording_studio_terms_and_conditions`
- Module: `RecordingStudioTermsAndConditions`
- Source: [bowerbird-app/RecordingStudio_terms_and_conditions](https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions)

This addon ships the **data shape, domain helpers, clickwrap Agree screen, admin Terms screens, a public published URL, and a host gate**. Signed-in people who still need to accept the current published Terms are sent to the same Agree screen. Recording Studio Users signup and post-auth use that path too.

## What's included

- **Recording Studio** 4.x gem pinned and configured
- **Devise** authentication with a pre-seeded admin user
- **Workspace**, **Folder**, and **Page** recordables seeded into the dummy host app
- **Terms** recordable (`RecordingStudioTermsAndConditions::Terms`, product label `"Terms"`) with Publishable opted in on the type
- **Acceptance** append-only table for later clickwrap receipts (not a recordable)
- **Domain helpers** on `RecordingStudioTermsAndConditions`: `current_published_for`, `accepted?`, `accept!`, `requires_acceptance?`
- **Agree screen** for the current published Terms (unchecked checkbox, gated Agree, `accept!`)
- **Gate** on the host `ApplicationController`: `requires_acceptance?` redirects to Agree until the live version is accepted, and again after a new publish
- **Users hook** on `RecordingStudioUser::Auth::BaseController` so after sign in / sign up land on Agree when acceptance is still required
- **Admin** create/edit Terms, Publishable publish, and simple acceptance coverage
- **Public Terms URL** at `/terms/:uuid/:slug` via Publishable
- **FlatPack** UI component library for all views
- **Dummy app** (`test/dummy/`) with a FlatPack sign-in screen, a home page on Recording Studio's default layout, mounted Recording Studio routes, and FlatPack's built-in rounded theme

Authenticated dummy pages use Recording Studio's shared default layout (`RecordingStudio::UsesDefaultLayout`) plus FlatPack CSS and JS. Devise keeps its own sign-in layout. Dummy `/docs/*` pages stay in the dummy app as a host-app sandbox; they are not the product README.

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

The login form is prefilled with these credentials for fast access.

### Useful routes

- `/` — dummy app home page
- `/users/sign_in` — Devise sign-in page
- `/recording_studio_terms_and_conditions` — Agree (clickwrap) screen on the Recording Studio default layout
- `/recording_studio_terms_and_conditions/admin/terms` — write and edit Terms
- `/admin` — Admin Terms section (Accessible on the Admin root)
- `/terms/:uuid/:slug` — public published Terms
- `/recording_studio` — redirect to `/` while the mounted Recording Studio engine remains data/API-focused
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

## Architecture

### Root recording pattern

The dummy host follows Recording Studio's root recording pattern:

- **Workspace** is the dummy content root. Users also registers shared **People**.
- **Folder** and **Page** demonstrate nested host recordables under the workspace root
- **Terms** is this gem's nested recordable under Workspace. Enable Publishable on the class with `RecordingStudio::Capabilities::Publishable.to` — installing the gem does not publish anything by itself
- **Acceptance** rows are receipts, not tree nodes: actor, terms recording id, terms snapshot id, timestamps, provenance
- Hosts ask the module for the live published version and whether an actor still needs to accept:
  ```ruby
  terms = RecordingStudioTermsAndConditions.current_published_for(workspace)
  RecordingStudioTermsAndConditions.requires_acceptance?(user, workspace)
  RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "clickwrap" })
  RecordingStudioTermsAndConditions.accepted?(user, workspace)
  ```
  Live means Publishable `currently_published?` (scheduled-in-the-future is not current). `indexable` is SEO and is not used for clickwrap.
- The gem includes `ForcesAcceptance` on the host `ApplicationController` and prepends `UsersAuthRedirect` on Users Auth. Both reuse `requires_acceptance?` and the mounted Agree screen. Auth, Agree, Admin, public Terms, and root switch stay reachable so people can sign in, accept, publish, or switch workspace.
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
| Users           | gemspec `recording_studio_user ~> 0.11`; dummy GitHub tag `v0.11.0` |
| Publishable     | gemspec `~> 0.2`; dummy GitHub tag `v0.2.1` |
| Attachable      | dummy GitHub tag `v0.5.1` (Users Profile needs it) |
| Root Switchable | dummy GitHub tag `v0.5.0` |
| FlatPack        | gemspec `>= 0.1.144`; dummy GitHub tag `v0.1.177` |
| Devise          | latest  |

The dummy Gemfile keeps `github:` sources so Bundler can fetch those gems. Hosts also need Publishable (and Users/Attachable) migrations from those gems — this addon only ships Terms and Acceptance migrations.

## Documentation

Engine internals from the original gem template stay in `docs/gem_template/` as architectural reference. This README and the dummy app are the source of truth for the addon.

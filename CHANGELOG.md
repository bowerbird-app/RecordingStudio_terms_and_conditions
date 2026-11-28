# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.26.0] - 2026-11-27

### Breaking
- `Outline.release` and `terms_release` refuse a no-op with `Outline::Unchanged` (API `invalid_input`, message `No changes to release`) when the outline and title match the last release.

### Fixed
- Release stays on the same Terms recording. A live outline no longer forks a second document of that kind, so `terms_release` returns the lineage id and `terms_documents` lists one row per kind.
- Outline seed strips only the generated number for that position (`1. ` for section 1, `1.1 ` for clause 1.1). Author section and clause writes keep the text as typed. A later seed on an existing outline does not rewrite the live body, the baseline, or `terms_id`.
- Split walks through a wrapping block so a single-block body keeps every heading as its own section.
- A live seeded document whose stored body is not yet the assembled outline is not treated as unreleased. Publish settings (status plus slug) stay on that snapshot and apply the slug.
- A Publishable publish whose only pending outline edit is a heading that the release-path repair strips back to the last release (for example `1. Scope` at position 1) no longer 422s. The slug is saved. An explicit no-op `terms_release` still 422s.
- A live outline release emits `PublishedEmitter` and does not draft then republish.

### Upgrade notes (0.25.1 → 0.26.0)
- No Terms migration. Pin `0.26.0`.
- Callers that treated a no-change `terms_release` as HTTP 200 with `released: false` now receive 422. The error message is `No changes to release`.
- Callers that stored the forked recording id from a live release should keep using the original lineage id. Old stray documents from 0.25.0 are not deleted automatically.
- Documents whose outline rows still store generated numbers render `1. 1. Scope` until a later outline release. `seed_outline` strips stored prefixes on section and clause rows only. It does not rewrite the live body or `terms_id`. Docs that 0.25.x collapsed into one section are not re-split.

## [0.25.1] - 2026-11-27

### Changed
- Terms MCP tool descriptions put a full stop on the short summary before the shared document blurb, so tools such as `terms_outline` read as sentences.

### Upgrade notes (0.25.0 → 0.25.1)
- No Terms migration. Pin `0.25.1`. Copy only; no host wiring change.

## [0.25.0] - 2026-11-27

### Added
- Operations API `terms_create` (`:edit`). Title, kind (`terms_and_condition` or `privacy_policy`), and body. Creates the document on the shared library through `TermsCreate` (the same path as Admin New) and seeds the outline. Refuses with KindPresence when that kind already exists. Returns the document and its outline.
- Operations API `terms_update` (`:edit`). Uses `TermsWrite`. Body only when the document has no outline. A rename of an outlined document is refused for now (`TermsWrite::OutlinePresent`, 422).
- `RecordingStudioTermsAndConditions::McpCopy.tool_names(api:)`. Operations lists documents, create, update, outline, section/clause reads and writes, changes, preview, and release. Public lists only the three clickwrap reads. Never an accept tool.

### Changed
- Dummy development dependencies: net-ssh 7.3.10, puma 8.1.2, rack-protection 4.2.2, and brakeman 8.1.1.
- Development Ruby is 3.3.14. Root puma is 8.1.2.
- `terms_documents`, outline/section/clause lookups, and the other authoring actions resolve when `context.recording` is AdminRoot, still via the shared library and `terms_id`.
- Admin New create calls `TermsCreate` instead of duplicating draft-and-seed.
- **Breaking:** every Terms authoring action registers only on the operations API. Public and other non-operations named APIs keep only the three clickwrap reads (`terms_pending_published_list`, `terms_current_published_for`, `terms_accepted`). Removed from public: `terms_documents`, `terms_outline`, `terms_section`, `terms_clause`, `terms_changes`, `terms_preview`, `terms_add_section`, `terms_edit_section`, `terms_move_section`, `terms_remove_section`, `terms_add_clause`, `terms_edit_clause`, `terms_move_clause`, `terms_remove_clause`, and `terms_release`.

### Upgrade notes (0.24.0 → 0.25.0)
- No Terms migration. Pin `0.25.0`.
- Enable `RecordingStudio::Capabilities::TermsAndConditions.to` on AdminRoot. Register AdminRoot on the operations API with the authoring actions (`terms_create`, `terms_update`, documents, outline/section/clause reads and writes, changes, preview, release). Drop those names from public Workspace and Terms type APIs.
- Hosts that load Recording Studio MCP include `RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :operations)` on the operations MCP server and `api: :public` for the three clickwrap reads. Public MCP must not list authoring tools.
- Callers that authored Terms on the public API (`/recording_studio_api/api/v1`) must move to the operations API (`/recording_studio_api/apis/operations/v1`) on AdminRoot.

## [0.24.0] - 2026-11-20

### Added
- `UsersAfterAuthPath` hooks Users' public `config.after_auth_path` (Users >= 0.37.0). Sign-in and sign-up land on Agree while live Terms are pending. Terms still does not depend on Users. `install!` does nothing when Users or the setting is absent, and it does not nest when it runs twice. A host callable set in an initializer is wrapped. Terms wins when it returns a path; nil hands over to the host callable.
- `config.users_after_auth_path` (default `true`). Set it to `false` to wire the landing path yourself.
- Default gate-exempt prefixes `recording_studio_user/auth` and `recording_studio_user/omniauth`, so sign-out still finishes while Terms are pending. Duplicates from a host that already appended them are ignored.

### Changed
- Development and the dummy pin Recording Studio `v7.8.0`, Flatpack `v0.2.0`, Accessible `v0.58.0`, Admin `v2.20.0`, API `v1.21.2`, Attachable `v0.34.0`, Cache `v0.8.0`, Icons `v0.5.0`, Logs `v0.9.0`, Metrics `v0.10.0`, Moveable `v6.1.0`, Publishable `v1.5.0`, and Trashable `v1.3.0`. The dummy also pins Notifications `v0.21.0`, Notifications Email `v0.7.0`, Broadcasts `v0.7.0`, Root Switchable `v0.17.0`, and Users `v0.42.1`. Internationalization stays `v0.3.0`.
- flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration.
- Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not.

### Upgrade notes (0.23.0 → 0.24.0)
- No Terms migration. Pin `0.24.0`. Hosts moving from 0.22.0 must also read 0.23.0's notes.
- Hosts on Users >= 0.37.0 get the Agree redirect automatically after sign-in and sign-up. Delete any host copy of `UsersAuthRedirect` or a host prepend of `after_sign_in_path_for`.
- Set `config.users_after_auth_path = false` to opt out.
- Set a host `config.after_auth_path` callable in an initializer. A `to_prepare` assignment after boot replaces the wrap. This gem does not add a `to_prepare` hook for that setting.
- Signup consent stays host wiring (`signup_notice_partials` and `after_registration`). This release does not restore `SignupAcceptance` or a Users view override.

## [0.23.0] - 2026-11-18

### Changed
- Signup consent is host wiring. The partial `recording_studio_terms_and_conditions/signup_notice` renders the continue-notice only when live terms exist. `SignupRegistration.call(user:, method:)` accepts each pending live document with `{ "source" => "signup", "method" => method.to_s }` for `:password`, `:oauth`, and `:otp`. `NotLive` skips that document. Any other error returns nil so account creation still succeeds. Receipts still store `body_digest`. The dummy registers that partial and callable in its Users initializer.
- `config.gate_exempt_controllers` lists controller paths the clickwrap skips. Defaults cover Agree, Admin, Publishable, and health. The host appends its auth controllers. The dummy adds `recording_studio_user/auth` and `recording_studio_user/omniauth`.
- `config.actor_name_search` is an optional callable `(relation, term)` for who-agreed search. The dummy matches email and profile name. With no callable, the name filter does not narrow the list.
- `recording_studio_user` is not a gemspec dependency. The dummy still pins tag `v0.36.0` and copies the Users sign-in lockout and sign-in link migrations.

### Removed
- `UsersAuthRedirect` and any prepend onto Users Auth. Users 0.36 has no after-sign-in or after-sign-up setting. `Auth::BaseController#after_sign_in_path_for` is private, and sign-in calls it with `public_send`. A host prepends a public method that returns `Gate.after_auth_path(self, user) || super`. The dummy does that for auth and OAuth callbacks.
- Engine registration of the signup notice and the `after_registration` hook. Terms does not reference Users.
- The Users view-path prepend, `app/views/recording_studio_user/auth/registrations/_extra_fields.html.erb`, and the `SignupAcceptance` prepend on `RegistrationsController`.

### Upgrade notes (0.22.0 → 0.23.0)
- Breaking. No Terms migration. Pin this gem at `0.23.0`. Drop `recording_studio_user` from the Terms gemspec. Keep it on the host if you use Users. The dummy pins tag `v0.36.0`.
- Add these lines where you configure Users:

```ruby
config.signup_notice_partials << "recording_studio_terms_and_conditions/signup_notice"
config.after_registration(RecordingStudioTermsAndConditions::SignupRegistration)
```

- In the Terms initializer, append auth controller paths and, if you search who agreed by name, set the callable:

```ruby
config.gate_exempt_controllers += %w[recording_studio_user/auth recording_studio_user/omniauth]
config.actor_name_search = ->(relation, term) { relation } # host narrows relation
```

- Delete a host override of `recording_studio_user/auth/registrations/_extra_fields` that only rendered the old notice. Delete any host copy of `UsersAuthRedirect`.
- Signup receipts use `source` `signup` plus the signup `method`. Agree for someone who already has an account is unchanged and still writes `continue_notice` when a new version is published.
- Users `0.36.0` runs `after_registration` from password confirmation, OAuth account creation, and OTP registration completion. `Directory.create_user!`, the operations create API, and seeds do not emit it. There is no invite method. Those accounts never saw the notice, so a host that only registers this callable does not write a signup receipt for them.
- Coming from Users `0.32` or `0.35`, copy the sign-in lockout and sign-in link migrations and migrate.

## [0.22.0] - 2026-11-16

### Changed
- Gemspec caps now stop at the next major. Accessible, Metrics, and Users move from `< 1.0` to `< 2.0`. Moveable moves from `< 6.0` to `< 7.0`. Floors stay: core `>= 7.0`, `< 8.0`; Accessible `>= 0.44.0`; Admin `>= 2.16.0`, `< 3.0`; Metrics `>= 0.9.0`; Moveable `>= 5.0`; Publishable `>= 1.0.0`, `< 2.0`; Users `>= 0.30.0`. Development and dummy pins are unchanged.

### Upgrade notes (0.21.0 → 0.22.0)
- No schema change. Pin this gem at `0.22.0`.
- Allow Accessible, Metrics, and Users below `2.0`, and Moveable below `7.0`. Lower bounds are unchanged. Core stays `< 8.0`, Admin stays `< 3.0`, and Publishable stays `< 2.0`.

## [0.21.0] - 2026-11-15

A person accepts Terms once. The live document for each kind sits on one shared library root, the same shape as People. Switching workspace does not ask again. Publishing a new version still asks everyone once.

### Added
- `RecordingStudioTermsAndConditions::Library`, a shared root (`root: true, shared: true`). `library_root(actor:)` finds or creates that one recording.
- Migration `create_recording_studio_terms_and_conditions_libraries`.

### Changed
- Terms `allowed_parent_types` is `RecordingStudioTermsAndConditions::Library`. Terms is an accessible child of that root, the same shape as Profile under People. The first writer is the access owner. Other people who can edit the admin root get edit on that document.
- Moveable allows an admin-root editor to move recordings in the library. The library itself still cannot hold a grant.
- Authoring API actions take `terms_id` and are registered on the workspace. The workspace grant is the access check. The document is not in that tree.
- Acceptance helpers no longer take a workspace. `current_published_for`, `current_published_by_kind`, `pending_published_list`, `pending_published_for`, `accepted?`, `requires_acceptance?`, and `reaccepting?` read the library.
- The gate ignores the current root and the first-accessible-root fallback.
- Admin creates under the library. The index lists every untrashed Terms recording.
- Workspace member API paths still authorize on that workspace. The payload is the library document.
- The dummy `authorize_write` allows a library write when the actor has Accessible `:edit` on the admin root. Accessible will not grant on the library itself.
- The dummy Tailwind build links `flat_pack` and each loaded `recording_studio*` gem into `test/dummy/vendor/engines` before `tailwindcss:build` and `tailwindcss:watch`, then scans those links. That is the Recording Studio gem template 0.3.0 pattern (`Gem.loaded_specs` `full_gem_path` instead of a list of machine install directories). Collapse and the other components pick up their utilities. A relative path to the system gem directory never left the repo, so those classes were missing from the CSS. That source list was already wrong on `main`. The links and `bundled_sources.css` are generated and stay out of git.
- Gemspec requires `recording_studio_publishable` `>= 1.0.0`, `< 2.0`. Development and the dummy pin tag `v1.0.0`.
- SoleLive's `after_service`, OutlinePublish's `around_service`, and the Published install latch register on `RecordingStudio.configuration.hooks`. `subscribe(:published)` is unchanged. OutlinePublish runs inside the Broadcasts 0.6.0 sent-publishable lock (`SentPublishableLock::PRIORITY`, which is 0).

### Upgrade notes (0.20.0 → 0.21.0)
- Breaking. Not a data migration. Do not backfill workspace Terms or old receipts.
- Pin `0.21.0` and Publishable `1.0.0` together. Featured In bumps Terms and Publishable in the same release. Copy the libraries migration and run `bin/rails db:migrate`.
- Register `RecordingStudioTermsAndConditions::Library` in `recordable_types`.
- Record Terms on `RecordingStudioTermsAndConditions.library_root(actor:)`.
- Drop the root argument from the helpers above, and drop `root:` from `recording_studio_terms_agree` and `recording_studio_terms_continue_notice`.
- `authorize_write` must allow staff writes on the library. A grant on that root is rejected. Enable Accessible on Terms. The gem bootstraps the writer.
- Move the outline, clause, and release API actions onto the workspace registration and pass `terms_id`. A workspace token cannot see a recording under the library.
- Require `recording_studio_publishable` `>= 1.0.0`, `< 2.0`. Publishable `1.0.0` removed `RecordingStudioPublishable.configuration.hooks`. SoleLive, OutlinePublish, and the Published latch register on `RecordingStudio.configuration.hooks`. `RecordingStudioPublishable.subscribe(:published)` is unchanged. There is no shim back to the old registry.
- OutlinePublish's `around_service` uses priority 200. Broadcasts 0.6.0 registers its sent-publishable lock at priority 0, so the release runs inside that lock even when it returns without calling the block.
- A `~> 0.20` constraint will not take `0.21.0`. A Publishable `< 1.0` constraint will not take `1.0.0`.

## [0.20.0] - 2026-11-15

Requires Recording Studio 7. Roots are created with `create_root_recording!`. `root_recording_for` only finds an existing root.

### Changed
- Gemspec requires `recording_studio` `>= 7.0`, `< 8.0`, Accessible `>= 0.44.0`, `< 1.0`, Admin `>= 2.16.0`, `< 3.0`, Metrics `>= 0.9.0`, `< 1.0`, Moveable `>= 5.0`, `< 6.0`, Publishable `>= 0.18.1`, `< 1.0`, and Users `>= 0.30.0`, `< 1.0`.
- Development and the dummy pin Recording Studio `v7.0.0`, Accessible `v0.44.0`, Admin `v2.16.0`, Metrics `v0.9.0`, Moveable `v5.0.0`, Publishable `v0.18.1`, API `v0.24.0`, Users `v0.30.0`, Trashable `v0.17.0`, Attachable `v0.28.0`, and Flatpack `v0.1.376`. API 0.24 requires Logs `v0.8.0`. Root Switchable `v0.15.0` and Internationalization `v0.2.2` reject core 7, so the dummy uses `v0.16.0` and `v0.3.0`. Cache stays `v0.6.3`. Icons stay `v0.2.1`. Puma is `8.1.0`. The dummy pins `msgpack >= 1.8.7`.
- Seeds and tests that created a root call `create_root_recording!(recordable, actor:)`. Lookups stay on `root_recording_for`.
- The dummy `authorize_write` still requires Accessible `:edit` (or `:admin` for Access rows). A present actor may create a root, where `root_recording` is nil.
- The dummy admin root query uses `Recording.kept`. Trashable 0.17 removed `kept_sql`. This gem does not call `RecordingStudio.kept_sql`.
- Admin root resolution uses `access_recording_resolver`, pointed at `RecordingStudioAccessible.admin_root`. Site screens also need Accessible `admin_root_resolver`. Admin 2.16 dropped `site_admin_recording_resolver`.
- The dummy copies core migration `20261114090000_add_root_recording_id_to_recording_studio_events`.
- The acceptance gate still uses `RecordingStudio.register_gate` and `RecordingStudio.check_gate`.

### Upgrade notes (0.19.1 → 0.20.0)
- Terms tables are unchanged. Copy core migration `20261114090000_add_root_recording_id_to_recording_studio_events` if `recording_studio_events.root_recording_id` is missing.
- Pin this gem at `0.20.0`. Require Recording Studio `>= 7.0`, `< 8.0` (tag `v7.0.0`) and the companion floors above.
- Replace `root_recording_for` calls that created a root with `create_root_recording!(recordable, actor:)`. Leave lookups on `root_recording_for` and handle `nil`.
- Keep `config.authorize_write`. A new root is authorized with `root_recording` nil. Do not set `allow_unauthorized_writes`.
- Drop `site_admin_recording_resolver`. Set Accessible `admin_root_resolver` to the kept admin root, and point Admin `access_recording_resolver` at `RecordingStudioAccessible.admin_root`. Replace `recording_studio_trashable_kept_sql` with `Recording.kept`.
- The gate name `recording_studio_terms_and_conditions.acceptance` and the `pending` check are unchanged.

## [0.19.1] - 2026-11-15

### Changed
- Allow recording_studio < 8.0 (core 7 phase 1).

### Upgrade notes (0.19.0 → 0.19.1)
- No schema change. Pin this gem at `0.19.1`. Gemspec `recording_studio` stays `>= 6.7.0` and now allows `< 8.0`. Development and dummy stay on core 6.x.

## [0.19.0] - 2026-11-14

### Added
- Clickwrap registers the Recording Studio gate `recording_studio_terms_and_conditions.acceptance` once at boot. The `pending` check uses the actor and an explicit root or the controller's acceptance root. Pending kinds deny with `redirect_to` set to the Agree path. `ForcesAcceptance` and post-auth redirects follow `RecordingStudio.check_gate`. A raised check denies, and a signed-in request still goes to Agree. Agree stays exempt, so that redirect does not loop.

### Removed
- Template capability `RecordingStudio::Capabilities::Example`.

### Changed
- Gemspec `recording_studio` is `>= 6.7.0`, `< 7`.
- `AcceptanceGateInstaller` runs from `to_prepare` only.
- Dummy lockfile updates `omniauth` to 2.4.1 (CVE-2026-63183).

### Upgrade notes (0.18.0 → 0.19.0)
- No schema change. Pin this gem at `0.19.0`. Require Recording Studio `>= 6.7.0`.
- Drop `include RecordingStudio::Capabilities::Example.to` if a host copied the dummy Workspace line.
- Hosts can disable or reorder the check with `config.gate_overrides` under `recording_studio_terms_and_conditions.acceptance` / `pending`.
- Agree, receipts, and the mounted path are unchanged.

## [0.18.0] - 2026-11-12

### Added
- Terms are authored as Section and Clause recordables under the Terms recording. Each has its own history. A clause edit revises that clause only.
- Release builds the parent `title` and `body` from the current outline, with section and clause numbers baked into the text, stores a manifest of the section and clause snapshots that went into it, and publishes through Publishable. Child edits do not publish and do not fire `published.recording_studio_terms_and_conditions`.
- Unreleased changes are computed by comparing the current outline to the last release manifest. A revert to the released wording is not a change. Admin shows that status, a per-clause review, and a Release action.
- Admin API actions, also available to MCP through `capability_action`: `terms_documents`, `terms_outline`, `terms_section`, `terms_clause`, `terms_changes`, `terms_preview`, `terms_add_section`, `terms_edit_section`, `terms_move_section`, `terms_remove_section`, `terms_add_clause`, `terms_edit_clause`, `terms_move_clause`, `terms_remove_clause`, and `terms_release`. Reads need admin `:view`. Writes need admin `:edit`. There is still no accept action.
- Idempotent rake task `recording_studio_terms_and_conditions:seed_outline`. It splits an existing body into sections and clauses and records the live version as the baseline manifest. It does not publish and does not write receipts.

### Changed
- Staff no longer edit the parent body directly. The parent text is rebuilt only at release. Every release is a new version people must accept again.
- Admin outline editing is a set of screens instead of one long form. The document page splits the live version from unreleased edits. Full text toggles the live wording and the next release. Sections and clauses are their own pages. Reorder is a drag-and-drop list. Clauses have no title field.
- Agreement history lists each released snapshot, newest first, with its agreement count. A snapshot is labelled Version N in release order, with the release date and time in the host time zone. The live row is marked Live. Opening one lists who agreed to that snapshot and when. Receipts stay grouped by `terms_id`. There is no acceptance schema change.
- Publishing a Terms document that already has an outline, from the Admin show page or from Publishable's publish path, goes through Release. The show page offers Release instead of Publish now. The hook still fires once, and one live copy per kind remains.
- `TermsWrite` raises `TermsWrite::OutlinePresent` when the document already has an outline. It still saves a document that has none.
- New dependency `recording_studio_moveable` `>= 4.1.0`, `< 5`. Releasing a live document moves its sections onto the new draft so section and clause ids stay put.

### Upgrade notes (0.17.0 → 0.18.0)
- Schema change. Copy migrations with `bin/rails generate recording_studio_terms_and_conditions:migrations` (or the install generator) and run `bin/rails db:migrate`. New tables are sections and clauses. Terms gains nullable `release_manifest` jsonb.
- Pin this gem at `0.18.0`. Add GitHub sources for `recording_studio_moveable` `v4.1.0` and `recording_studio_icons` `v0.2.0` if Bundler cannot find them on RubyGems.
- Register `RecordingStudioTermsAndConditions::Section` and `RecordingStudioTermsAndConditions::Clause` in `recordable_types`.
- Run `ACTOR_TYPE=User ACTOR_ID=<staff id> bin/rails recording_studio_terms_and_conditions:seed_outline` once. It is safe to run again. It does not create a Terms version and does not touch receipts.
- Public reads stay `terms_pending_published_list`, `terms_current_published_for`, and `terms_accepted`. List `terms_documents` on the workspace. List the outline, edit, preview, and release actions on `RecordingStudioTermsAndConditions::Terms`. Set `auto_capability_actions: false` on those types so only the listed actions are exposed. Grant the API client Accessible on the admin root (`:view` to read, `:edit` to change or release). There is no API or MCP accept action.
- Consumers that only read a published title and body need the version bump, the migrations, and the seed. They do not need a new receipt system. Agree, public URLs, the gate, helpers, `:terms_acceptances`, and the hook payload are unchanged.
- `terms_release` is an admin API action and an MCP `capability_action`. There is no accept action. `TermsWrite` cannot overwrite a document that already has an outline.

## [0.17.0] - 2026-11-12

### Added
- Recording Studio API capability actions for the access grant's actor: `terms_pending_published_list`, `terms_current_published_for`, and `terms_accepted`. They wrap the existing domain helpers. Register behind `defined?(::RecordingStudioApi)` on each named API via `configuration.each_api`. A second register of the same name on an API raises. Required role is Accessible `:view` on the workspace root (the same floor the Agree screen and gate use). Hosts enable `RecordingStudio::Capabilities::TermsAndConditions.to` on the root type and list the actions on that type's API. No runtime gemspec dependency on Recording Studio API. Metrics stay on `metrics.rb`. API clients may not accept Terms. `terms_accept_pending` is not registered.

### Upgrade notes (0.16.0 → 0.17.0)
- No schema change. Pin this gem at `0.17.0`.
- Recording Studio API is optional. Dummy mounts API `v0.21.3`. A host that wants the actions adds Recording Studio API, includes `RecordingStudio::Capabilities::TermsAndConditions.to` on the workspace/root type, and lists `terms_pending_published_list`, `terms_current_published_for`, and `terms_accepted` in that type's `capability_actions`. API clients may not accept Terms.
- Actor always comes from the access grant (`access_grant.actor`). Do not send an actor in the request. Under a client-credentials token that actor is the ApiClient.

## [0.16.0] - 2026-11-06

### Changed
- Admin authorization fails closed when Accessible or Admin is missing, the actor is blank, or the admin access recording is missing. It used to allow the request in those cases.
- Admin write parent is the current Workspace only when Accessible grants `:view` on it, otherwise the first Accessible workspace root for that actor. It no longer picks the first Workspace in the table.
- Admin Terms and person-receipt queries go through that Accessible Terms scope. Site admins who already hold `:view` on the Admin access recording still see every version and receipt.
- Clickwrap fallback (`first_root_with_live_terms`) only considers Accessible `:view` roots for the actor. It no longer walks every root. Live Terms on a root the actor cannot view no longer gate them. Users Auth still resolves Root Switchable Current (the host default root when the actor is unsigned) so create-password can show host Terms without scanning every tenant.
- Development and dummy pin Recording Studio `v6.5.0`, Accessible `v0.24.2`, Metrics `v0.7.3`, Logs `v0.7.4`, Trashable `v0.12.3`, and Users `v0.27.1`. Admin stays `v2.9.1`. Dummy `config.authorize_write` allows AccessCreationContext only for `RecordingStudio::Access` rows. Access writes outside that context need Accessible `:admin` on the root. Every other write needs Accessible `:edit` on the root. Dummy does not allow Profile writes from persisted User identity. Users first-Profile on the shared People root still needs Accessible `:edit` there (Users bootstrap gap, not a host exception).
- Gemspec `recording_studio_accessible` is `>= 0.24.2`, `< 1` (was `~> 0.8`) so hosts resolve `root_recordings_for`.

### Upgrade notes (0.15.0 → 0.16.0)
- No schema change. Pin this gem at `0.16.0`.
- Require `recording_studio_accessible` `>= 0.24.2`. Pin Recording Studio `v6.5.0` in development and dummy. Leave Admin at `v2.9.1` when the host follows the 2.5.1 policy plus this dummy's existing 2.9.1 pin.
- Drafting Terms while switched to the Admin root needs Accessible `:view` on a Workspace. Otherwise New/create says “Pick a workspace first.” instead of attaching the draft to an arbitrary Workspace.
- Host-wide clickwrap that relied on “first root with live Terms” must put those Terms on a root the actor can `:view`, keep the actor on that root, or leave them on the Root Switchable default root (signup). Signed-in users no longer fall back to another tenant's Terms.

## [0.15.0] - 2026-11-05

### Changed
- Gemspec `recording_studio` is `>= 6.3.0`, `< 7` (was `~> 4.2`). Dependents can resolve core `v6.3.0` with Admin `v2.9.1`, Root Switchable `v0.11.5`, and Cache `>= 6.1`.
- Development and dummy pin Recording Studio `v6.3.0` and FlatPack `v0.1.341`. Dummy and development pin Admin `v2.9.1`. Dummy pins Root Switchable `v0.11.5`. Sibling GitHub tags move only as far as Bundler needs for those pins. Dummy and development pin Logs `v0.7.3` because Admin `v2.9.1` requires it. Logs is not a Terms gemspec dependency.
- Gem and dummy controllers use core 6 `recording_studio_layout` instead of removed `UsesDefaultLayout`. Gem views still render `recording_studio/default_layout`. `terms_page_nav` writes `:title` plus dummy `page_nav_back_*` slots and calls `flat_pack_page_nav(round: true, style: :default, back_href:, back_tooltip:)`. Core 6 removed `recording_studio_page_nav`. Dummy Admin hub override uses Admin `recording_studio_admin_page_heading` and still puts every hub action in the PageTitle slot.
- Dummy Users Auth sets `config.layout = "application"` because Users 0.27 `recording_studio_layout` falls through to core `DEFAULT_LAYOUT` when the setting is nil. Dummy `layouts/application` loads `flat_pack/application`. Dummy default layout renders `flat_pack_page_nav_tag` for Root Switchable 0.11.5. Root Switchable `config.layout` is a callable because `Layout.accept` rejects a symbol method name. Accessible 0.24 grants need a manager who already holds the role. Attachable 0.22 dropped `ImageLibrary`; dummy Workspace no longer enables `:image_library`.
- Public `config.layout` defaults to `nil` (core default layout). Set a layout name or callable accepted by `RecordingStudio::Layout.accept` when Agree screens should use a host layout.
- Lockfiles resolve `view_component` `>= 4.14` (GHSA-8qw7-6phv-7q6p) and `rack` `>= 3.2.8` (GHSA-2j8w-xcrc-x985, GHSA-5v64-555j-wjxm, GHSA-p8x9-v4hv-2w4g, GHSA-wvg4-6p58-3gh3).

### Upgrade notes (0.14.2 → 0.15.0)
- No schema change. Pin this gem at `0.15.0`.
- Require Recording Studio `>= 6.3.0` and below 7. Pin FlatPack git tag `v0.1.341`. Pin Admin `v2.9.1` when the dummy or host uses Admin. Pin Root Switchable `v0.11.5` when the host uses it.
- Replace `include RecordingStudio::UsesDefaultLayout` with `recording_studio_layout`. Hosts that override `recording_studio/default_layout` keep PageNav `with_back` / `with_close` / `with_item`. Do not pass removed PageNav keywords (`back_icon`, `anchor_label`, `right_slot`) or Card `style:`.
- Reload Flatpack CSS. Do not rerun `bin/rails generate flat_pack:install`.
- Terms public API (`accept!`, pending/live helpers, Agree helpers) is unchanged.

## [0.14.2] - 2026-10-29

### Removed
- Tracked SimpleCov output under `coverage/` and `test/dummy/coverage/`.

### Upgrade notes (0.14.1 → 0.14.2)
- No schema change. Pin this gem at `0.14.2`.
- Stop tracking SimpleCov output. `coverage/` and `test/dummy/coverage/` are gitignored.
- Keep the 0.14.0 FlatPack `v0.1.311` pin (`view_component` `>= 4.14`).

## [0.14.1] - 2026-10-29

### Removed
- Dropped the FlatPack Button `url:` → `href:` prepend. FlatPack Button already renders an `<a>` when given `href:`.
- The dummy Terms hub override was the only Button caller that passed `url:` (it relied on the shim). It now passes `href:`. Links need FlatPack `>= 0.1.196` (`href:` on Button). Recording Studio Admin 2.4.0 already passes `href:` on its own section view; this gem's Admin DSL `url:` keys on `link` / `action` are unchanged. Gemspec now requires `recording_studio_admin` `>= 2.0.6`, `< 3` so hosts cannot land on Admin 2.0.0–2.0.5 (those versions pass `url:` into FlatPack Button and section buttons stay inert).

### Upgrade notes (0.14.0 → 0.14.1)
- No schema change. Pin this gem at `0.14.1`.
- Pass `href:` to FlatPack `Button::Component` for link-style buttons. This gem no longer copies `url:` onto `href:`. Recording Studio Admin section `link` / resource `action` still use `url:` on their own DSL. FlatPack stays at git tag `v0.1.311` from 0.14.0; development and dummy Admin pin stays `v2.4.0` (at or below `v2.5.1`). Install `recording_studio_admin` `>= 2.0.6` and below 3.0 (gemspec floor; Admin 2.0.0–2.0.5 passed `url:` into FlatPack Button).

## [0.14.0] - 2026-10-28

### Changed
- Development and dummy pin FlatPack `v0.1.311`. That gemspec allows `view_component` `>= 4.14`, `< 5` (GHSA-8qw7-6phv-7q6p). The previous FlatPack tag (`v0.1.213`) required `view_component ~> 4.12.0`.
- Dummy default layout PageNav uses `with_back`, `with_close`, and `with_item`. Keywords removed in FlatPack 0.1.274 (`right_slot`, `anchor_href`, `secondary_anchor_href`, `back_label`) raise on 0.1.311.
- Dummy pins Root Switchable `v0.10.0`. That tag's switch page already uses PageNav `with_close` and a Card without `style:`. Dummy does not override the view. `v0.11.0` needs Recording Studio 6.1.
- Development and dummy pin Admin `v2.4.0` (gemspec still `~> 2.0`). Admin 2.3.0 widget cards passed Card `style: :outlined`, which FlatPack 0.1.311 rejects.
- Lockfiles resolve `view_component` `>= 4.14`, `crass` `>= 1.0.8`, and dummy `net-ssh` `>= 7.3.5`.

### Upgrade notes (0.13.4 → 0.14.0)
- No schema change. Pin this gem at `0.14.0`.
- Pin `flat_pack` to git tag `v0.1.311` and run `bundle update view_component`. Render each component instance once.
- Hosts that override `recording_studio/default_layout` must use the FlatPack `>= 0.1.274` PageNav API (`with_back`, `with_close`, `with_item`). Do not pass `right_slot`, `anchor_href`, or `secondary_anchor_href`.
- Dummy and hosts can pin Root Switchable `v0.10.0` on FlatPack 0.1.311. A host that still mounts `v0.9.0` must stop passing PageNav `anchor_label:` and Card `style:` on the switch page.
- Pin `recording_studio_admin` to `v2.4.0` or `v2.5.1` when the host FlatPack is 0.1.311. Stay below Admin `v2.7.0` (`v2.7.0` is the first to require Recording Studio `>= 6.1` and `flat_pack >= 0.1.315`).
- Reload Flatpack CSS. Do not rerun `bin/rails generate flat_pack:install`.

## [0.13.4] - 2026-10-22

### Changed
- Allow `recording_studio_metrics` `>= 0.3.0, < 1.0` (CI tested with Metrics 0.5.0). No code change.
- Point `.ruby-version` at 3.3.12 so GitHub runners can install Ruby (3.3.6 is gone on ubuntu-26.04).

### Upgrade notes (0.13.3 → 0.13.4)
- No schema change. Pin this gem at `0.13.4`. Ceiling for `recording_studio_metrics` is `< 1.0`. No code change.
- Development Ruby is 3.3.12.

## [0.13.3] - 2026-10-20

### Changed
- Agrees over time hides x-axis labels (`chart_options` `xaxis.labels.show: false`) and defaults the Metrics window to Admin preset `last_30_days`. Who agreed still defaults to `last_4_weeks`.

### Upgrade notes (0.13.2 → 0.13.3)
- No schema change. Pin this gem at `0.13.3`.

## [0.13.2] - 2026-10-20

### Changed
- Terms Admin hub puts the Terms and conditions and Privacy Policy widgets in the compact row at the top, with Agrees over time in the full-width row below.

### Fixed
- Who agreed applies the date range to `accepted_at` through Admin’s date-range filter (`field: :accepted_at`, not a dotted table string), so changing the range changes the people table.
- Agrees over time maps Metrics timeseries `{ date:, value: }` rows to `{ x:, y: }` points, so the chart counts the same acceptances as Who agreed.

### Upgrade notes (0.13.1 → 0.13.2)
- No schema change. Pin this gem at `0.13.2`.

## [0.13.1] - 2026-10-20

### Changed
- Allow `recording_studio_metrics` `>= 0.3.0, < 0.6`. Development and dummy Gemfiles pin GitHub tag `v0.5.0`.
- Agrees over time passes `RecordingStudioMetrics::Admin.chart_series` through unchanged. Metrics 0.5.0 already emits `{ x:, y: }` points, so the widget no longer sums `[date, value]` pairs.

### Upgrade notes (0.13.0 → 0.13.1)
- No schema change. Pin this gem at `0.13.1`.
- Pin `recording_studio_metrics` to `>= 0.3.0, < 0.6` (tag `v0.5.0`). Hub charts expect `{ x:, y: }` points from `chart_series`.

## [0.13.0] - 2026-10-19

### Added
- Terms Admin hub chart widget `widgets.terms.acceptances_over_time` reads `terms_acceptances.over_time` through `RecordingStudioMetrics::Admin` and links to the Who agreed screen. Default window is `last_4_weeks`, same as Who agreed.
- Who agreed (`recording_studio_terms_acceptances`) has an Admin `date_range` filter on acceptance `accepted_at` (default `last_4_weeks`), plus `agreed_terms` and `agreed_privacy` filters. The people table no longer has an Actions column.

### Upgrade notes (0.12.0 → 0.13.0)
- No schema change. Pin this gem at `0.13.0`.
- No new gems. The hub chart uses the existing Metrics Admin adapter and Admin widget registry.

## [0.12.0] - 2026-10-15

### Added
- `terms_acceptances.over_time` accepts `group_by=kind` (`terms_and_condition` / `privacy_policy`, from the accepted Terms snapshot) and now carries unit `count` and a description. Ungrouped counts are unchanged. No migration.

### Changed
- Require `recording_studio_metrics` `>= 0.3.0, < 0.4`. Development and dummy Gemfiles pin `v0.3.1`. Each metric's `catalog_metadata` is what Metrics 0.3 discovery (and MCP 0.17) lists. Permission stays in `api_authorize` (`Api::Access.can_view?`). This gem still does not call `RecordingStudioMetrics::Api.register!`.

### Upgrade notes (0.11.0 → 0.12.0)
- No schema change. Pin this gem at `0.12.0`.
- Pin `recording_studio_metrics` to `>= 0.3.0, < 0.4` (tag `v0.3.1`).
- When RecordingStudio API is present, the host still calls `RecordingStudioMetrics::Api.register!(api: :operations)` once.

## [0.11.0] - 2026-10-15

### Added
- After a Terms recording becomes currently published, the gem emits
  `published.recording_studio_terms_and_conditions` with `recording_id` and
  `terms_id`. The event is after commit. It follows Publishable
  `published.recording_studio_publishable`, including scheduled
  `WindowTransitionJob` go-live. The payload has no actors, emails, or body.
- `RecordingStudioTermsAndConditions.reaccepting_actors_for(recording_id:, terms_id:)`
  returns distinct `[actor_type, actor_id]` pairs for people who accepted an
  older snapshot of that kind and have not accepted this one. First-time
  users are omitted. Hosts drop staff and send their own mail.
- `RecordingStudioTermsAndConditions::Published.subscribe` wraps the event
  name the same way `RecordingStudioPublishable.subscribe` does.

### Fixed
- Live-version comparison uses `<=>` so two live rows of one kind no longer
  raise `NoMethodError` on `Array#<=` during `current_published_for`, the
  clickwrap gate, or `reaccepting_actors_for`.
- Scheduled `WindowTransitionJob` go-live drafts the previous live row of
  that kind (SoleLive) before the host query runs.
- A subscriber exception is reported with `Rails.error` and does not fail
  Publishable `Update` or skip SoleLive. The emit claim is written only
  after the instrument returns, so a retry can notify again.
- A second successful job run for the same window does not emit again.
  Concurrent claimants compare against a fresh create so only one wins
  when `idempotency_mode` is `:return_existing`.
- A lookup failure is reported and skips the Terms event. Subscriber
  errors no longer swallow SoleLive or claim failures.
- `reaccepting_actors_for` loads sibling ids with a kind-scoped relation
  and a batched live check instead of per-recording `currently_published?`.

### Upgrade notes (0.10.1 → 0.11.0)
- No schema change. Pin this gem at `0.11.0`.
- Subscribe to `RecordingStudioTermsAndConditions::Published::EVENT` when a
  new live Terms or Privacy Policy version should notify people who already
  agreed. Then call `reaccepting_actors_for` with the payload ids. Do not
  subscribe to raw Publishable `published` for this job.
- The clickwrap gate is unchanged. This event does not send mail.

## [0.10.1] - 2026-10-09

### Fixed
- Site-wide Terms metrics resolve the admin root with `site_admin_recording_resolver`, falling back to `access_recording_resolver`. If that resolver raises, `can_view?` denies access instead of failing metrics discovery.

### Upgrade notes (0.10.0 → 0.10.1)
- No schema change. Pin this gem at `0.10.1`.

## [0.10.0] - 2026-10-09

Site-wide Terms acceptance metrics register with Recording Studio Metrics for the operations API.

### Added
- `RecordingStudioTermsAndConditions::Metrics.register!` registers `:terms_acceptances`
  (`blast_radius: :site`) with RecordingStudioMetrics. Metrics:
  `terms_acceptances.total` (receipt count),   `terms_acceptances.over_time`
  (`accepted_at` series), and `terms_acceptances.by_version` (breakdown on
  `terms_recording_id`, including receipts for trashed Terms recordings).
  Each metric is exposed on `:operations` only. `api_authorize` uses
  `RecordingStudioTermsAndConditions::Api::Access.can_view?` (AdminRoot `:view`,
  the same Accessible check Admin screens use).
- Runtime dependency `recording_studio_metrics` `~> 0.2` (GitHub tag `v0.2.0`).

### Upgrade notes (0.9.0 → 0.10.0)
- Bump to `0.10.0`. No migration.
- Add `recording_studio_metrics` at tag `v0.2.0`.
- This gem does not call `RecordingStudioMetrics::Api.register!`. When
  RecordingStudio API is present, the host registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

## [0.9.0] - 2026-10-08

### Added
- Customer-facing Agree, signup continue-notice, checkbox, flashes, and `NotLive` copy live under `recording_studio.terms_and_conditions.*`. The gem ships English only in `config/locales/en.yml`. Hosts add other languages.
- Dummy demos English and French via Recording Studio Internationalization (`v0.1.2`, dummy Gemfile only). A language selector sits in PageNav. Dummy `fr.yml` covers every engine key. Dummy `/agree_helper` Accept and Continue labels follow the dummy locale. French checkbox and continue-notice copy uses natural articles (`les conditions générales`, `la politique de confidentialité`).

### Changed
- Dummy FlatPack moves to `v0.1.209` so kit chrome can follow the locale.
- Dummy and development pin Recording Studio `v4.3.0`, Admin `v2.0.7`, and Users `v0.16.0` (from main).
- Helper `text:` on `recording_studio_terms_agree_button` and other copy arguments still win over locale defaults. Stored Terms bodies and version titles stay data.

### Upgrade notes (0.8.1 → 0.9.0)
- No schema change. Pin this gem at `0.9.0`. English screens stay the same.
- To offer another language, copy `recording_studio.terms_and_conditions.*` from `config/locales/en.yml` into the host (`config/locales/<locale>.yml`) and list that locale in `config.i18n.available_locales`. Dummy `test/dummy/config/locales/fr.yml` is a complete starting point.
- Do not add `RecordingStudio_Internationalization` as a gem dependency of this engine. Use plain Rails I18n. Internationalization is a host (and dummy) concern.
- `recording_studio_terms_agree_button(text: "Accept")` and other passed strings still override the locale. Leave the English default (`"Agree"`) to follow I18n.
- Staff Admin screens, dummy page titles, and developer `ArgumentError`s stay English. Dummy `/agree_helper` Accept and Continue follow the dummy locale.

## [0.8.1] - 2026-10-08

### Changed
- Dummy and development pin Admin `v2.0.6` and FlatPack `v0.1.207`.

### Upgrade notes (0.8.0 → 0.8.1)
- No schema change. Pin this gem at `0.8.1` if you want those dummy/dev pins. `version.rb` stayed `0.8.0` on that tag.

## [0.8.0] - 2026-10-08

### Changed
- Admin Terms hub actions are **Terms and Condition page**, **Privacy Policy page**, **Edit Terms**, and **Edit Privacy Policy**. Edit and page links use the secondary button style. **New**, **All versions**, and **Agree stats** are no longer hub actions.
- Hub cards are **Terms and conditions** and **Privacy Policy**. The count is the large number, with **users agreed** in smaller text under it. The versions screen is the table only. Live rows sort above drafts, newest first in each group.
- Who agreed lists one row per person (name, terms date, privacy date, View), newest first, 25 per page. View opens that person's agreements, newest first. The list searches by name or email.
- The engine terms index redirects to `/admin/screens/recording_studio_terms`. Agree is `/recording_studio_terms_and_conditions/acceptance`. The engine root redirects there. Dummy `/admin/sections` and `/admin/sections/terms` redirect to `/admin`.
- Agree keeps main’s Flatpack Collapse rows for each live document, with the continue notice and **Continue** underneath. Continue and the “By continuing…” line stay after someone has already agreed. Agreeing again to the same live copy does not change the receipt time.
- Dummy home is a single row of secondary links: Admin, the live Terms page, the live Privacy Policy page, and Helper. Dummy root switch uses the switch gem's PageNav only. Dummy `/agree_helper` shows the checkbox and the “By continuing…” notice even after the signed-in person has already agreed.

### Upgrade notes (0.7.8 → 0.8.0)
- No schema change. Pin this gem at `0.8.0`. Hosts that linked the hub **New**, **All versions**, or **Agree stats** actions should link **Edit Terms**, **Edit Privacy Policy**, and the live page links instead. The engine terms index now redirects to the versions screen. Hub **Live** and **Agrees** cards are **Terms and conditions** and **Privacy Policy**. Agree still uses Collapse rows; Continue stays available after a prior agreement.

## [0.7.8] - 2026-10-08

### Changed
- Accept page title is first-time copy when the signed-in person has no acceptance receipts yet: **Terms and Conditions**, **Privacy Policy**, or **Terms and Conditions and Privacy Policy**. Anyone who has accepted a version before still sees **We have updated our…** for the pending kinds.

### Upgrade notes (0.7.7 → 0.7.8)
- No schema change. Pin this gem at `0.7.8`. First-time Accept titles no longer say the documents were updated.

## [0.7.7] - 2026-10-08

### Fixed
- Continue-notice “Terms & Conditions” and “privacy policy” triggers are `<button type="button">` with `data-modal-id` (no `href`). FlatPack’s modal controller opens on `[data-modal-id]` without `preventDefault`, so the previous `href="#…"` link let Turbo re-GET the page and the modal closed immediately.
- Signed-in `Gate.pending_for` / `required?` / `after_auth_path` and `AcceptancesController` use the same `root_for_acceptance` helper as signup (`root_for_signup`). A current root with no live Terms falls back to the first root that has them, so OAuth (and anyone who skipped create-password) still land on the full-page Agree screen.

### Upgrade notes (0.7.3 → 0.7.7)
- No schema change. Pin this gem at `0.7.7`. Rebuild host Tailwind so the unstyled continue-notice button classes are generated. OAuth and other signed-in visitors whose current workspace has no live Terms are gated against the host’s published Terms.

## [0.7.3] - 2026-09-24

### Changed
- Host checkbox helper (`recording_studio_terms_agree`) wraps in `mt-3 mb-6` so there is a comfortable gap before the host Agree / Accept button (was `my-3`).
- Dummy `/agree_helper` clickwrap form uses `recording_studio_terms_agree_button` (Flatpack `style: :primary`) for Accept, same path as Accept Continue.

### Upgrade notes (0.7.2 → 0.7.3)
- No schema change. Pin this gem at `0.7.3`. Hosts that put a button under `recording_studio_terms_agree` get more space above it. Prefer `recording_studio_terms_agree_button` (or Flatpack Button `style: :primary`) so the CTA fills theme primary.

## [0.7.2] - 2026-09-23

### Changed
- Requires `recording_studio_user` `>= 0.12.2`. Dummy and root Gemfiles pin Users at GitHub tag `v0.12.2`. That release links `flat_pack/application` on the auth layout, so Sign in and Sign up primary buttons fill.

### Upgrade notes (0.7.1 → 0.7.2)
- No schema change. Pin this gem at `0.7.2` and `recording_studio_user` at `0.12.2`. Rebuild is not required for the button fill; Users auth layout loads `flat_pack/application`.

## [0.7.1] - 2026-09-23

### Changed
- Continue-notice wrapper is `mt-3 mb-3` (was `mt-3 mb-6`). Accept and create-password share that gap above **Continue** and **Sign up**.

### Upgrade notes (0.7.0 → 0.7.1)
- No schema change. Pin this gem at `0.7.1`. The helper owns the gap, so hosts do not override Accept or create-password spacing.

## [0.7.0] - 2026-09-23

### Added
- Terms `kind` enum: `terms_and_condition` | `privacy_policy`. One document lineage per kind per workspace. Admin New is blocked when any recording of that kind already exists; later versions come from edit/fork only.
- SoleLive is per kind: publishing Privacy Policy drafts other live privacy rows, not Terms.
- Gate pending list is 0..2 (terms-only, privacy-only, or both). Accept / continue-notice / Agree accept every pending live version (one receipt row each).
- Public Privacy Policy path `/privacy/:uuid/:slug` (Terms stay on `/terms/:uuid/:slug`). `published_url` for privacy rows uses the privacy path.
- Continue-notice includes “and privacy policy” plus a Privacy modal when a privacy document is pending. Agree checkbox copy includes “and privacy policy”; the privacy link opens in a new tab (`target=_blank`). Terms links stay same-tab.
- Admin Type column / select label **Privacy Policy**.

### Changed
- Continue-notice wraps in `mt-3 mb-6` so it has spacing above the host button. `link: false` still turns links and modals off (Accept uses this).
- Accept PageTitle follows pending kinds: terms only, privacy only, or **We have updated our terms and conditions and privacy policy.** when both are pending. Collapse rows only list the pending kinds.

### Upgrade notes (0.6.6 → 0.7.0)
- Run `bin/rails generate recording_studio_terms_and_conditions:migrations` and `bin/rails db:migrate`. Existing Terms rows default to `terms_and_condition`.
- Hosts that mount Publishable at `/` get `/privacy/:uuid/:slug` from this gem’s route append. Keep `/terms/:uuid/:slug`.
- Accept and host Agree helpers now `accept!` every pending kind. Gate stays on until both live kinds (when present) have receipts.
- No gate-flash revival. Users soft create-password slot is unchanged.

## [0.6.6] - 2026-09-23

### Changed
- The acceptance gate no longer flashes “We've updated our Terms and Conditions”. Accept still says **We have updated our terms and conditions.**

### Upgrade notes (0.6.5 → 0.6.6)
- No schema change. Pin this gem at `0.6.6`. A new live version still sends people to Accept. That redirect does not set a notice. Hosts that showed the same sentence in their own flash can drop it; the page title already says the terms changed.

## [0.6.5] - 2026-09-23

### Added
- `recording_studio_terms_continue_notice` takes `link:` (default `true`). `link: false` keeps the “By continuing…” sentence and renders “Terms & Conditions” as plain text, with no Flatpack Link and no modal.

### Changed
- The Accept screen passes `link: false`. Live copy is already in the closed Collapse, so Continue does not open a second copy in a modal. Signup and other hosts still get the link and modal unless they pass `link: false`.
- Accept PageTitle is **We have updated our terms and conditions.** for a first visit and a re-gate. The Collapse title stays the live Terms name.
- Requires FlatPack `>= 0.1.196` (dummy GitHub tag `v0.1.196`).

### Upgrade notes (0.6.4 → 0.6.5)
- No schema change. Pin this gem at `0.6.5` and FlatPack `>= 0.1.196`. Rebuild host Tailwind. Default continue-notice still links “Terms & Conditions” and opens the modal. Pass `link: false` when the page already shows the terms (Accept does this). Hosts that overrode `acceptances/show` only to drop that link can delete the override.
- Accept PageTitle no longer uses the live Terms heading on a first visit. It is “We have updated our terms and conditions.” The Collapse title is still the Terms name.

## [0.6.4] - 2026-09-23

### Fixed
- Accept **Continue** (and other engine screens) append `flat_pack/application` via `content_for :head`. Helper already passes `style: :primary` / `data-fp-style="primary"`; without the kit sheet Flatpack only has a Tailwind `border`, so Continue looked outline/secondary on hosts that only loaded `flat_pack/variables` (Users dummy re-gate). Hosts should still load `flat_pack/application` from `_default_layout_head` with Tailwind last.

### Changed
- Re-gate Accept PageTitle is **We have updated our terms and conditions.** First-time Accept still uses the live Terms heading. Collapse title stays the Terms name.

### Upgrade notes (0.6.3 → 0.6.4)
- No schema change. Pin this gem at `0.6.4`. Keep FlatPack `>= 0.1.195`. Prefer linking `flat_pack/application` in the host `_default_layout_head` (dummy already does); the engine also injects it for Agree/Accept/Admin so primary buttons paint if the host forgot. Re-gate Accept heading copy is the sentence above; flash stays “We've updated our Terms and Conditions”.

## [0.6.3] - 2026-09-22

### Changed
- `Gate.root_for_signup` treats a current root with no live Terms as empty and falls back to `first_root_with_live_terms`. Unsigned create-password still shows the continue notice when any root has live Terms. Signed-in `root_for` / `pending_for` / `required?` are unchanged — post-auth Agree still uses the workspace you are in.
- Agree no longer shows the on-page “Terms updated” Flatpack Alert or the “You already agreed…” paragraph. Re-accept keeps the flash “We've updated our Terms and Conditions” and the calendar date subtitle. The mounted Accept screen uses `recording_studio_terms_continue_notice` (no checkbox) and a **Continue** button; POST writes `{ "source" => "continue_notice" }`. Continue-notice sits in `mb-6` above Continue on Accept only.
- Requires FlatPack `>= 0.1.195` (dummy GitHub tag `v0.1.195`) for theme-primary checkboxes. Host checkbox helper spacing uses `my-3`.

### Upgrade notes (0.6.2 → 0.6.3)
- No schema change. Hosts that overrode `acceptances/show` can delete the override after bumping if they only kept the old re-accept Alert or checkbox.
- Signup continue-notice follows `root_for_signup` fallback. Leave `ForcesAcceptance` and `UsersAuthRedirect` on the current root.
- Pin FlatPack `>= 0.1.195` and rebuild host Tailwind. Re-accept flash copy is “We've updated our Terms and Conditions”. Accept screen button is **Continue**; receipts from that POST use `continue_notice`.

## [0.6.2] - 2026-09-22

### Changed
- The gem Agree screen no longer applies optional scroll-to-end. Dummy leaves `require_scroll_to_end` off. Agree stays clickable; the required checkbox is the yes. Hosts can still wrap their own copy with the scroll helper.
- First-time gate no longer flashes “One more thing — agree to the terms.” The Agree screen is the notice. Re-accept still flashes “Terms changed. Agree again.”
- Successful Agree no longer flashes “You're in. Thanks for reading.” It just sends people on.

### Upgrade notes (0.6.1 → 0.6.2)
- No schema change. The mounted Agree screen ignores `config.require_scroll_to_end`. Dummy no longer opts in. Hosts that still want a scroll gate wrap their own live copy with `recording_studio_terms_scroll_to_end` and `recording_studio_terms_agree_button`.
- First-time redirects to Agree no longer set a flash. A new live version still flashes “Terms changed. Agree again.”
- Agree no longer flashes “You're in. Thanks for reading.” after a successful tick.

## [0.6.1] - 2026-09-21

### Added
- Users create-password override of `recording_studio_user/auth/registrations/_extra_fields` renders `recording_studio_terms_continue_notice` when live Terms are still pending. Signup does not render the checkbox helper.
- `recording_studio_terms_continue_notice` is `text-xs` and muted (`text-[var(--surface-muted-content-color)]`) by default. `size:` accepts `:xs` (default) or `:sm`. Unknown sizes fall back to `:xs`. The Terms & Conditions link uses Flatpack Link primary + underline so it stays clickable against muted copy. The modal body is the standalone terms document (PageTitle + date + Flatpack Content), shared with the public show.
- Soft `SignupAcceptance` on Users `RegistrationsController`: after a successful `create_password`, pending live Terms are `accept!`ed with provenance `source` `continue_notice`. Continuing the form is the agreement. `ForcesAcceptance` and `UsersAuthRedirect` still gate. `NotLive` does not fail signup.

### Changed
- Requires `recording_studio_user` `>= 0.12.1` (create-password extra_fields slot). Dummy and root Gemfiles pin Users at GitHub tag `v0.12.1`.

### Upgrade notes (0.6.0 → 0.6.1)
- Pin `recording_studio_user` to `0.12.1` or later. No Terms or Acceptance schema change. No user-table timestamp.
- Signup writes receipts with `{ "source" => "continue_notice" }` when create-password succeeds. Hosts that already call `accept!` on that POST stay idempotent. Leave the Agree screen and post-auth redirect in place.
- Continue-notice is xs and muted by default. Pass `size: :sm` for the larger size. The Terms link opens a modal with the standalone terms document (title, date, Flatpack Content).

## [0.6.0] - 2026-09-21

### Added
- Optional `config.app_name` (string, default blank). When blank, `app_name` uses `RecordingStudioSiteSettings.name_for` if that constant and method exist. Site Settings is not a gem dependency.
- Host helper `recording_studio_terms_continue_notice` next to the checkbox helper. Copy is “By continuing, you agree to [app name]'s Terms & Conditions”. The linked words open a Flatpack Modal whose body is still `FlatPack::Content`. Host POST calls `accept!` with provenance `source` `continue_notice`. Dummy `/agree_helper` posts both helpers and clears the gate.

### Changed
- Agree keeps the post-auth gate. It no longer sets PageNav. Live copy sits in a Flatpack Collapse (closed by default) wrapping `FlatPack::Content`. The Collapse title is the live Terms heading. Re-accept Alert stays above. The checkbox starts ticked. Agree stays at the bottom. Optional scroll-to-end is unchanged.

### Upgrade notes (0.5.0 → 0.6.0)
- Set `config.app_name` in the host initializer if you want a fixed product name. Leave it blank to use Site Settings when that gem is loaded. No schema change.
- Drop `recording_studio_terms_continue_notice` onto a host form when the product uses a continue notice instead of (or besides) the checkbox. On that POST, call `accept!` with `{ "source" => "continue_notice" }`. Do not replace `recording_studio_terms_agree`.
- Hosts that override `recording_studio/default_layout` should skip PageNav when `content_for?(:skip_page_nav)` is set, so Agree has no PageNav. Dummy already does this.

## [0.5.0] - 2026-09-17

### Changed
- Requires `recording_studio_publishable` `~> 0.3` (dummy GitHub tag `v0.3.1`).
- Admin term show uses Publishable `QuickActions` (Draft / scheduled date / Published). The old primary **Publish** button that opened the stuffed edit form is gone. Preview and View live in that menu. Opening term show ensures a Publishable child so Preview is not 404 on a brand-new draft. Publish settings is still the hub at `/recordings/:id/publishable/edit`.
- Public Terms templates render `publishable_preview_badge` on Preview. Preview is `/recordings/:id/publishable/preview`, not a query param on `/terms/:uuid/:slug`.
- Saving a **live** Terms recording forks a new draft. The published copy stays live until someone publishes the draft. Publishing that draft drafts the previous live version in the workspace. People who agreed to the old copy stay agreed until the new copy is live; they are not auto-ticked for the new one.

### Upgrade notes (0.4.x → 0.5.0)

Pin `recording_studio_publishable` `v0.3.1` (`~> 0.3` in the gemspec). No Terms or Acceptance schema change.

Replace a custom **Publish** button that linked to the old edit form with `RecordingStudioPublishable::QuickActions::Component` (or `terms_publishable_quick_actions`). Inline publish stays on the host page. Hosts that overrode `edit.html.erb` as one form should switch to the hub plus Schedule / SEO / Social screens. Public templates can render `publishable_preview_badge`.

Do not `revise` a live Terms recording to change wording. Use admin Edit (or `TermsWrite`) so the live copy stays frozen. Publish the draft when the new wording should gate people again.

## [0.4.1] - 2026-09-17

### Changed
- Admin Terms hub no longer renders Accessible avatars or **+ Access** in PageNav. Hub actions stay New / All versions / Agree stats. Manage grants on Accessible’s own screens.
- Dummy and gem-mounted Terms screens stay on default-layout PageNav only (no Terms demo TopNav, workspace switcher, or Sign out). That TopNav drop shipped in 0.4.0; this release keeps it off those pages and hides **+ Access**.
- FlatPack pin is **v0.1.186** (gemspec `>= 0.1.186`). Agree, public, and admin Terms copy wrap in `FlatPack::Content` (`fp-content`).
- Dummy sample Terms title is **Terms and Conditions v1.0**, with a longer body. The public slug stays `terms-and-conditions`.
- Admin Terms is a registered Recording Studio Admin resource. The All versions table uses `admin_action` for Open / Edit / Users. Engine write screens authorize with `authorize_resource!` and wrap saves in `perform_recording_studio_admin_action!`. New and Edit need Accessible `:edit` on the Admin root.

### Upgrade notes (0.4.0 → 0.4.1)
- No schema change. The Admin hub shortcut to Accessible is gone. Open the Accessible mount (dummy: `/admin/access`) to grant or edit access.
- Pin FlatPack `>= 0.1.186` and rebuild host Tailwind so `fp-content` is in the CSS.
- Engine Admin definition reload drops Terms section/screen/widget constants before `load`, so development reload does not duplicate hub widgets.

## [0.4.0] - 2026-09-16

### Removed
- Template Configuration knobs `api_key`, `enable_feature_x`, and `timeout`. Product config is `mount_path`, `require_scroll_to_end`, and `capture_request_provenance`.
- Unused example `create_recording_studio_terms_and_conditions_pages` migration. Dummy never applied it; hosts that already copied it locally can leave the unused table.
- Terms `category` / `kind` (`terms`, `privacy`, `usage`) and `change_note`. Clickwrap is one live Terms document per workspace, not a set of document types. Re-gate still uses the existing receipt, not a changelog field.

### Added
- Append-only Acceptance receipts store a SHA-256 `body_digest` of the live Terms body at `accept!` time. `Acceptance#receipt_contract` returns actor, version ids, timestamp, digest, algorithm, and provenance. Existing receipts keep a null digest and are not rewritten.
- Optional `config.capture_request_provenance` (default off). When true, the gem Agree screen adds IP and user agent to provenance on new accepts.
- `accept!` is idempotent for the same actor and Terms snapshot. A unique index on actor + recording + snapshot returns the existing receipt on retry. A later published revision still inserts a new row.
- `accept!` refuses drafts, unpublished, and scheduled-but-not-live versions (`RecordingStudioTermsAndConditions::NotLive`). The Agree screen flashes and does not write a receipt.
- Re-gate Agree shows a Flatpack Alert (“You already agreed”) when the person has a receipt for an older snapshot of that Terms recording and the live snapshot is a different row. First-time Agree does not show it.
- Domain helpers: `pending_published_for` / `pending_published_list` (the live Terms the actor still needs) and `reaccepting?`.

### Changed
- Admin hub Flatpack buttons (`New`, `All versions`, `Agree stats`, widget `More`) pass `href` so they navigate. Recording Studio Admin still sends `url:`, which Flatpack ignores as a dead `<button>`.
- Admin hub title is **Terms and Conditions**. The versions screen is **All versions** (live and drafts; table heading matches). Receipts are **Agree stats**, with the table headed **Users**. The live count widget is **Live**.
- Dummy sample Terms title is **Terms and Conditions**. The public slug is `terms-and-conditions`. Agree, public, and admin show use the version date as the subtitle.
- Admin edit title is **Edit**. Engine Terms index primary action is **New**.
- Admin new Terms page title is **New Terms and Conditions**.
- Dummy default layout no longer renders Flatpack TopNav (Terms demo bar and workspace switcher). Pages stay on default-layout PageNav (back/close).
- Scroll-to-end no longer deadlocks Agree when `IntersectionObserver` is missing. Already-visible sentinels unlock immediately. The checkbox is still required. Scroll-to-end stays optional (default off). The Stimulus controller is self-contained (no extra importmap module).

### Upgrade notes (0.3.x → 0.4.0)

Copy this gem's migrations, then `bin/rails db:migrate`:

- `body_digest` on acceptances. Do not backfill old receipts.
- Unique index on actor + recording + snapshot. The migration drops `index_rstac_acceptances_on_actor_and_version` only if that name exists, then adds it unique. If migrate fails, resolve duplicate actor+snapshot rows first. Do not rewrite those rows.
- If a 0.4.0 preview added `category`, `kind`, or `change_note` on Terms, the follow-up migration drops those columns.

Delete `config.api_key`, `config.enable_feature_x`, `config.timeout`, and `RECORDING_STUDIO_TERMS_AND_CONDITIONS_API_KEY`. Unknown keys are ignored. Drop `config.required_categories` if you copied a preview initializer.

Behavior hosts must account for:

- Host `accept!` callers must pass a live published version. Rescue `NotLive`. Retrying the same actor and snapshot returns the existing receipt and does not rewrite provenance or digest. Callers cannot spoof `body_digest` in provenance.
- The gem Agree screen and host checkbox helper still use `pending_published_list` (zero or one live Terms).
- The host gate and Users post-auth hook stay on until that pending set is empty.
- Leave `capture_request_provenance` off unless the gem Agree screen should store IP and user agent.
- If you opt into `require_scroll_to_end`, pin the engine Stimulus controllers. Missing IntersectionObserver leaves Agree enabled.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.26.0...HEAD
[0.26.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.25.1...v0.26.0
[0.25.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.25.0...v0.25.1
[0.25.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.24.0...v0.25.0
[0.24.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.23.0...v0.24.0
[0.23.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.22.0...v0.23.0
[0.22.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.21.0...v0.22.0
[0.21.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.20.0...v0.21.0
[0.20.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.19.1...v0.20.0
[0.19.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.19.0...v0.19.1
[0.19.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.14.2...v0.15.0
[0.14.2]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.14.1...v0.14.2
[0.14.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.13.4...v0.14.0
[0.6.2]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.6.2
[0.6.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.6.1
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.6.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.5.0
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.4.0
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.3.0
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.2.0
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/releases/tag/v0.1.0

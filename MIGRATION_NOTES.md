# Migration Notes

## Host install

```bash
bin/rails generate recording_studio_terms_and_conditions:install
bin/rails db:migrate
```

That copies Terms and Acceptance migrations, mounts the engine, writes `config/initializers/recording_studio_terms_and_conditions.rb`, and pins the scroll-to-end Stimulus controller when `config/importmap.rb` exists.

Then:

- Register `RecordingStudioTermsAndConditions::Library`, `Terms`, `Section`, and `Clause` in `recordable_types`.
- Mount Publishable at `/`.
- Enable Admin `section :terms` on an Admin root and grant Accessible access.
- Publish with Publishable `QuickActions` on term show, or the Publish settings hub. Do not add a custom publish action.

The host includes the gate on `ApplicationController`. The gate is `recording_studio_terms_and_conditions.acceptance` on `RecordingStudio.check_gate`. Defaults already exempt `recording_studio_user/auth` and `recording_studio_user/omniauth`. Append any other auth controllers to `config.gate_exempt_controllers`. Set `config.actor_name_search` for who-agreed. Signup is separate. Where you configure Users, append `recording_studio_terms_and_conditions/signup_notice` to `signup_notice_partials` and register `SignupRegistration` with `after_registration`. That callable calls `accept!` with provenance `source` `signup` and `method` `password`, `oauth`, or `otp`. On Users >= 0.37.0, Terms hooks `config.after_auth_path` so sign-in and sign-up land on Agree while live Terms are pending. Set `config.users_after_auth_path = false` to wire that yourself. Set a host callable in an initializer. A `to_prepare` assignment replaces the wrap. Agree stays in place when a new version is published.

## Upgrade from 0.25.0 to 0.25.1

No Terms schema change. Pin `0.25.1`. MCP tool descriptions now end the short summary with a full stop before the shared document blurb. No host wiring change.

## Upgrade from 0.24.0 to 0.25.0

No Terms schema change. Pin `0.25.0`.

This is a breaking API change. Authoring actions leave the public API. Public (and any other non-operations named API) keeps only `terms_pending_published_list`, `terms_current_published_for`, and `terms_accepted`.

Enable `RecordingStudio::Capabilities::TermsAndConditions.to` on AdminRoot. Register AdminRoot on the operations API with `terms_create`, `terms_update`, `terms_documents`, outline/section/clause reads and writes, changes, preview, and release. Remove those names from the public Workspace and Terms type registrations.

Hosts that load Recording Studio MCP include Terms tools on the operations MCP server:

```ruby
include_tools(*RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :operations))
```

Public MCP stays on the three clickwrap reads:

```ruby
include_tools(*RecordingStudioTermsAndConditions::McpCopy.tool_names(api: :public))
```

Callers that authored Terms on `/recording_studio_api/api/v1` (Workspace) must move to `/recording_studio_api/apis/operations/v1` on AdminRoot.

## Upgrade from 0.23.0 to 0.24.0

No Terms schema change. Pin `0.24.0`. Hosts moving from 0.22.0 must also read the 0.23.0 notes. `recording_studio_user` is still not a Terms dependency. The dummy pins Users `v0.42.1`.

Hosts on Users >= 0.37.0 get the Agree redirect automatically after sign-in and sign-up. Delete any host copy of `UsersAuthRedirect` or a host prepend of `after_sign_in_path_for` / `after_sign_up_path_for`.

Set `config.users_after_auth_path = false` to opt out and assign `RecordingStudioUser.config.after_auth_path` yourself. Put that assignment in an initializer. A `to_prepare` block that runs after boot replaces the wrap. This gem does not re-install the wrap from `to_prepare`.

`recording_studio_user/auth` and `recording_studio_user/omniauth` are on the default exempt list, so sign-out still works while Terms are pending. A host that already appended them can leave that line.

flat_pack 0.2.0 is supported. Hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration. Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not. Development moved off Attachable `v0.31.0` and Cache `v0.7.0`.

## Upgrade from 0.22.0 to 0.23.0

No Terms schema change. Pin `0.23.0`. `recording_studio_user` is not a Terms dependency. Keep it on the host. The dummy pins tag `v0.36.0`.

The engine does not install signup and does not touch Users controllers. Add these lines where you configure Users:

```ruby
config.signup_notice_partials << "recording_studio_terms_and_conditions/signup_notice"
config.after_registration(RecordingStudioTermsAndConditions::SignupRegistration)
```

On the Terms initializer:

```ruby
config.gate_exempt_controllers += %w[recording_studio_user/auth recording_studio_user/omniauth]
config.actor_name_search = ->(relation, term) { relation } # replace with the host's actor match
```

The install generator comments those two Terms settings.

The notice renders only when live terms exist. Continuing signup is the agreement. There is no checkbox.

Users 0.36 runs `after_registration` for password, OAuth, and OTP signup only. Staff create, the operations API, `Directory.create_user!`, and seeds do not emit it. There is no invite path on the hook. Those accounts do not get a signup receipt. Users 0.36 also has no after-sign-in config. `Auth::BaseController#after_sign_in_path_for` is private, and sign-in calls it with `public_send`, so the private method raises. Prepend a public `after_sign_in_path_for` and `after_sign_up_path_for` on the auth controller (and the OAuth callbacks controller) that return `Gate.after_auth_path(self, user) || super`. Do not add that prepend inside Terms.

Delete a host `recording_studio_user/auth/registrations/_extra_fields` override that only existed for the old continue-notice. Accept on the re-gate screen is unchanged and still writes `continue_notice`. Receipts still store `body_digest`.

Delete a host `recording_studio_user/auth/registrations/_extra_fields` override that only existed for the old continue-notice. Accept on the re-gate screen is unchanged and still writes `continue_notice`. Receipts still store `body_digest`.

If the host is coming from Users `0.32` or `0.35`, copy the Users sign-in lockout and sign-in link migrations and migrate. Terms itself adds no migration.

After migrating an existing database, seed the outline once:

```bash
ACTOR_TYPE=User ACTOR_ID=<staff id> bin/rails recording_studio_terms_and_conditions:seed_outline
```

That splits each current body into sections and clauses and, for a live document, records that version as the baseline manifest. It does not publish and does not write receipts. Running it again does nothing when the outline is already there.

## Upgrade from 0.21.0 to 0.22.0

No schema change. Pin `0.22.0`. Accessible, Metrics, and Users are capped at `< 2.0`. Moveable is capped at `< 7.0`. Floors are unchanged. Core stays `< 8.0`, Admin stays `< 3.0`, and Publishable stays `< 2.0`.

## Upgrade from 0.20.0 to 0.21.0

Breaking. A person accepts the live Terms once. The document lives on one shared library root, the same shape as People. Switching workspace does not ask again. A new published version still asks once.

Copy the libraries migration and migrate. Register `RecordingStudioTermsAndConditions::Library` in `recordable_types`. There is no backfill of workspace Terms or old receipts.

Record Terms with `RecordingStudioTermsAndConditions.library_root(actor:)`. Drop the root argument from the acceptance helpers. Accessible refuses a grant on the library. Point `authorize_write` at staff some other way. The dummy allows the write when the actor has Accessible `:edit` on the admin root.

Workspace member API paths stay. They authorize on that workspace and read the library. Register the outline and release actions on the workspace and pass `terms_id`. Terms is an accessible child of the library. The first writer is the access owner.

Require Publishable `>= 1.0.0`, `< 2.0`. Pin tag `v1.0.0` (this gem previously pinned `v0.18.1`). Publishable 1.0.0 deleted `RecordingStudioPublishable.configuration.hooks`. Do not register service hooks there. `RecordingStudioPublishable.subscribe(:published)` still works. Featured In bumps Terms and Publishable in the same release.

## Upgrade from 0.19.1 to 0.20.0

Terms tables are unchanged. Pin `0.20.0`. Require Recording Studio `>= 7.0`, `< 8.0`. Copy core migration `20261114090000_add_root_recording_id_to_recording_studio_events` if `recording_studio_events.root_recording_id` is missing.

Create a root with `RecordingStudio.create_root_recording!(recordable, actor:)`. `root_recording_for` only finds an existing root and returns nil when there is none. Set `config.authorize_write`. A new root is authorized with `root_recording` nil.

Gemspec floors are Accessible `>= 0.44.0`, `< 1.0`, Admin `>= 2.16.0`, `< 3.0`, Metrics `>= 0.9.0`, `< 1.0`, Moveable `>= 5.0`, `< 6.0`, Publishable `>= 0.18.1`, `< 1.0`, and Users `>= 0.30.0`, `< 1.0`. Drop `site_admin_recording_resolver`. Set Accessible `admin_root_resolver` to the kept admin root, and point Admin `access_recording_resolver` at `RecordingStudioAccessible.admin_root`. Replace `recording_studio_trashable_kept_sql` with `Recording.kept`.

The gate `recording_studio_terms_and_conditions.acceptance` still registers with `RecordingStudio.register_gate`. `ForcesAcceptance` and post-auth redirects still follow `RecordingStudio.check_gate`.

## Upgrade from 0.19.0 to 0.19.1

No schema change. Pin `0.19.1`. Gemspec `recording_studio` stays `>= 6.7.0` and now allows `< 8.0`. Development and dummy stay on core 6.x.

## Upgrade from 0.18.0 to 0.19.0

No schema change. Pin `0.19.0`. Require Recording Studio `>= 6.7.0`, `< 7` (gates shipped in 6.7.0). The clickwrap registers `recording_studio_terms_and_conditions.acceptance` once at boot. The check is `pending`. It uses the actor and an explicit `root:` or the controller's acceptance root. Pending kinds deny with `redirect_to` set to the Agree path. `ForcesAcceptance` and post-auth redirects follow that decision. A raised check denies with no redirect, and a signed-in request still goes to Agree. Agree stays exempt, so that redirect does not loop.

Hosts can change priority or disable the check with `config.gate_overrides` under `recording_studio_terms_and_conditions.acceptance` / `pending`.

`RecordingStudio::Capabilities::Example` is removed. Drop `include RecordingStudio::Capabilities::Example.to` if a host copied the dummy Workspace line. Agree, receipts, and the mounted path are unchanged.

## Upgrade from 0.17.0 to 0.18.0

Schema change. Pin `0.18.0`. Generate migrations and run `bin/rails db:migrate`. New tables are `recording_studio_terms_and_conditions_sections` and `recording_studio_terms_and_conditions_clauses`. `recording_studio_terms_and_conditions_terms` gains nullable `release_manifest` jsonb.

Add GitHub sources for `recording_studio_moveable` tag `v4.1.0` and `recording_studio_icons` tag `v0.2.0`. The gemspec requires Moveable `>= 4.1.0`, `< 5`. Register Section and Clause next to Terms in `recordable_types`.

Run the seed task above. Staff then edit sections and clauses and use Release. Release is the only path that rebuilds the parent text and publishes it. A child edit does not fire `published.recording_studio_terms_and_conditions`. Every release that changes the document is a new version people must accept. On a document that already has an outline, the Admin show page offers Release instead of Publish now. Publishable's publish action for that document also goes through Release, so it cannot store a stale parent body. The hook still fires once per release, and SoleLive still keeps one live copy per kind.

`TermsWrite` remains for callers outside the Admin screens. It still forks or revises a Terms document that has no outline. Once that document has sections, `TermsWrite` raises `RecordingStudioTermsAndConditions::TermsWrite::OutlinePresent` and does not write the body. Edit the section or clause, then release.

Public API actions are unchanged: `terms_pending_published_list`, `terms_current_published_for`, `terms_accepted`. Add `terms_documents` to the workspace `capability_actions`. Add the outline, edit, preview, and release actions to `RecordingStudioTermsAndConditions::Terms`. Set `auto_capability_actions: false` on both. Grant the API client Accessible `:view` or `:edit` on the admin root, matching the Admin screens. MCP uses `capability_action`. Do not add an accept tool. There is no accept action.

Agree, `/terms/:uuid/:slug`, `/privacy/:uuid/:slug`, the gate, helpers, `:terms_acceptances`, locale keys, and the hook payload (`recording_id`, `terms_id`) are unchanged. Consumers that only read the published title and body need this version bump, the migrations, and the seed. Receipts still point at the parent Terms snapshot.

## Upgrade from 0.15.0 to 0.16.0

No schema change. Pin this gem at `0.16.0`. Require Accessible `>= 0.24.2`, `< 1`. Development and dummy pin Recording Studio `v6.5.0`, Accessible `v0.24.2`, Metrics `v0.7.3`, Logs `v0.7.4`, Trashable `v0.12.3`, and Users `v0.27.1`. Admin stays `v2.9.1`. Admin screens deny when Accessible is missing. Drafting from the Admin root needs `:view` on a Workspace. Clickwrap fallback only uses Accessible `:view` roots for the signed-in person. Unsigned create-password still uses the Root Switchable current/default root. Recording Studio 6.5 requires `config.authorize_write` and an actor on writes. Dummy allows AccessCreationContext only for `RecordingStudio::Access` rows. Access writes outside that context need Accessible `:admin` on the root. Every other write needs Accessible `:edit` on the root. Dummy does not allow Profile writes from persisted User identity. Users first-Profile on the shared People root still needs Accessible `:edit` there (Users bootstrap gap, not a host exception). Hosts should authorize with Accessible.

## Upgrade from 0.14.2 to 0.15.0

No schema change. Pin this gem at `0.15.0`. Require Recording Studio `>= 6.3.0`, `< 7`. Pin FlatPack `v0.1.341` and Admin `v2.9.1` when the host uses Admin. Dummy pins Root Switchable `v0.11.5`. Use `recording_studio_layout` instead of `UsesDefaultLayout`. `terms_page_nav` uses `flat_pack_page_nav`. Hosts that override default layout should render `flat_pack_page_nav_tag` for Root Switchable pages. Users Auth 0.27 needs `config.layout` set when the host does not want core `DEFAULT_LAYOUT`. Terms `config.layout` defaults to `nil` (core default layout). Terms public API is unchanged.

## Upgrade from 0.14.1 to 0.14.2

No schema change. Pin this gem at `0.14.2`. Stop tracking SimpleCov output. Keep FlatPack `v0.1.311`.

## Upgrade from 0.14.0 to 0.14.1

No schema change. Pin this gem at `0.14.1`. Pass `href:` to FlatPack `Button::Component` for link-style buttons. This gem no longer copies `url:` onto `href:`. Recording Studio Admin section `link` / resource `action` still use `url:` on their own DSL. FlatPack stays at git tag `v0.1.311` from 0.14.0. Install `recording_studio_admin` `>= 2.0.6` and below 3.0.

## Upgrade from 0.13.4 to 0.14.0

No schema change. Pin this gem at `0.14.0`. Pin `flat_pack` to git tag `v0.1.311` and run `bundle update view_component` so `view_component` is `>= 4.14` (GHSA-8qw7-6phv-7q6p). Dummy default layout PageNav uses `with_back`, `with_close`, and `with_item`. Dummy pins Root Switchable `v0.10.0` (switch page already uses PageNav `with_close` and a Card without `style:`). Pin Admin to `v2.4.0` or `v2.5.1` (stay below Admin `v2.7.0`; `v2.7.0` is the first to require Recording Studio `>= 6.1` and `flat_pack >= 0.1.315`) so widget cards do not pass removed Card `style:`. A host that still mounts Root Switchable `v0.9.0` must stop passing PageNav `anchor_label:` and Card `style:` on the switch page. Reload Flatpack CSS.

## Upgrade from 0.13.2 to 0.13.3

No schema change. Pin this gem at `0.13.3`. Agrees over time hides x-axis labels (`chart_options` `xaxis.labels.show: false`) and reads Admin `last_30_days`. Who agreed still defaults to `last_4_weeks`.

## Upgrade from 0.13.1 to 0.13.2

No schema change. Pin this gem at `0.13.2`. The Terms hub compact row holds Terms and conditions and Privacy Policy; Agrees over time stays below. Who agreed filters people by `accepted_at`. Agrees over time plots `{ x:, y: }` points from the timeseries `date`/`value` rows.

## Upgrade from 0.13.0 to 0.13.1

No schema change. Pin this gem at `0.13.1`. Require `recording_studio_metrics` `>= 0.3.0, < 0.6` (tag `v0.5.0`). Agrees over time passes `{ x:, y: }` points from `chart_series` through to Admin.

## Upgrade from 0.12.0 to 0.13.0

No schema change. Pin this gem at `0.13.0`. The Terms Admin hub adds an Agrees over time chart from `terms_acceptances.over_time` with a `last_4_weeks` default, matching Who agreed. Who agreed filters by `accepted_at`, agreed Terms, and agreed Privacy. The people table has no Actions column. Metrics stay registered as they were in 0.12.0.

## Upgrade from 0.11.0 to 0.12.0

No schema change. Pin this gem at `0.12.0`. Require `recording_studio_metrics` `>= 0.3.0, < 0.4` (tag `v0.3.1`). `terms_acceptances.over_time` accepts `group_by=kind`. Permission stays in `api_authorize`. When RecordingStudio API is present, the host still calls `RecordingStudioMetrics::Api.register!(api: :operations)`.

## Upgrade from 0.10.1 to 0.11.0

No schema change. Pin this gem at `0.11.0`. After a Terms recording becomes currently published, subscribe to `published.recording_studio_terms_and_conditions` and call `reaccepting_actors_for(recording_id:, terms_id:)`. The payload is those two ids. Hosts drop staff and send their own mail. Rescue subscriber errors; the gem already reports them and still drafts the previous live row. A later job can notify again if the subscriber raised before the emit was claimed. The claim is `log_event!` (`record!`); a denying `authorize_write` drops it. A destroyed user can still appear in the list (no FK from acceptances to users). The clickwrap gate is unchanged.

## Upgrade from 0.9.0 to 0.10.0

No schema change. Pin this gem at `0.10.0` and add `recording_studio_metrics` at tag `v0.2.0`. The gem registers `:terms_acceptances` metrics. When RecordingStudio API is present, the host calls `RecordingStudioMetrics::Api.register!(api: :operations)`. Staff with AdminRoot `:view` can read them.

## Upgrade from 0.8.1 to 0.9.0

No schema change. Customer-facing Agree, signup continue-notice, checkbox, flashes, and `NotLive` copy now look up `recording_studio.terms_and_conditions.*`. The gem ships English only. Copy a host locale file from `config/locales/en.yml` (or dummy `fr.yml`) to offer another language. Do not add `RecordingStudio_Internationalization` to this gemspec. Passed helper text such as `recording_studio_terms_agree_button(text: "Accept")` still wins. Stored Terms bodies and version titles stay untranslated. Staff Admin, dummy page titles, and developer errors stay English. Dummy `/agree_helper` Accept and Continue labels follow the dummy locale.

## Upgrade from 0.8.0 to 0.8.1

No schema change. Dummy and development pin Admin `v2.0.6` and FlatPack `v0.1.207`.

## Upgrade from 0.7.8 to 0.8.0

No schema change. The Admin Terms hub no longer shows **New**, **All versions**, or **Agree stats**. The actions are the live Terms page, the live Privacy Policy page, **Edit Terms**, and **Edit Privacy Policy**. Those page links are secondary. Hub cards are **Terms and conditions** and **Privacy Policy**. The count is large, and **users agreed** sits under it in smaller text. The versions screen is the table only, live rows first. `/recording_studio_terms_and_conditions/admin/terms` redirects to that screen. Agree is `/acceptance` on the mount. The engine root redirects there. `/admin/sections/terms` redirects to `/admin`. Who agreed searches name or email. Agree keeps Flatpack Collapse rows for each live document, then the continue notice and **Continue**. Continue and the “By continuing…” line stay after someone has already agreed. A second agree on the same live copy does not change the receipt time.

## Upgrade from 0.7.7 to 0.7.8

No schema change. Accept PageTitle for a first-time accepter (no receipt on record) is “Terms and Conditions”, “Privacy Policy”, or “Terms and Conditions and Privacy Policy”. A later live version still uses “We have updated our…”.

## Upgrade from 0.7.3 to 0.7.7

No schema change. Continue-notice “Terms & Conditions” and “privacy policy” are `<button type="button">` with `data-modal-id` (no `href`). Signed-in gating uses the same `root_for_acceptance` fallback as signup, so OAuth users whose current workspace has no live Terms still see the Agree screen. Rebuild host Tailwind for the trigger classes.

## Upgrade from 0.7.2 to 0.7.3

No schema change. `recording_studio_terms_agree` wraps in `mt-3 mb-6` (was `my-3`) so the gap before the host Agree / Accept button is more comfortable. Prefer `recording_studio_terms_agree_button` or Flatpack Button `style: :primary` for that CTA.

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
- Recording Studio 6.x (`>= 6.3.0`, `< 7` in the gemspec; dummy GitHub tag `v6.7.0`)
- Accessible dummy tag `v0.32.0` and Root Switchable dummy tag `v0.15.0`
- FlatPack dummy tag `v0.1.357`
- Publishable dummy tag `v0.15.0` (gemspec `~> 0.6`)
- Users `>= 0.12.2` (dummy GitHub tag `v0.28.1`)
- Admin dummy tag `v2.13.0` (gemspec `>= 2.0.6`, `< 3`)
- API GitHub tag `v0.23.1` (not a gemspec dependency; Publishable 0.15 and Attachable 0.23 require it)
- Trashable dummy tag `v0.14.0` (`purge_at` migration)
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

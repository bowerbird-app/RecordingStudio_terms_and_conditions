# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.4] - 2026-09-25

### Changed
- Admin Terms hub actions are **Terms and Condition page**, **Privacy Policy page**, **Edit Terms**, and **Edit Privacy Policy**. Edit actions use the secondary button style. **New**, **All versions**, and **Agree stats** are no longer hub actions.
- Dummy home is a single row of links: Admin, the live Terms page, the live Privacy Policy page, and Helper. The demo cards are gone.
- Dummy `/admin/sections` redirects to `/admin`.
- Dummy root switch uses the switch gem's PageNav only. The host layout no longer adds a second one.
- Who agreed lists one row per person (name, terms date, privacy date, View), newest first, 25 per page. View opens that person's agreements, newest first. The list searches by name or email.
- Hub cards are **Terms and conditions** and **Privacy Policy**. The count is the large number, with **users agreed** in smaller text under it. The versions screen is the table only. Live rows sort above drafts, newest first in each group.
- The engine terms index redirects to `/admin/screens/recording_studio_terms`. Public Terms stay on `/terms/:uuid/:slug`. Agree is `/recording_studio_terms_and_conditions/acceptance`. The engine root redirects there. Dummy `/admin/sections/terms` redirects to `/admin`.
- Dummy home and hub page links use the secondary button style. Dummy `/agree_helper` shows the checkbox and the “By continuing…” notice even after the signed-in person has already agreed.

### Upgrade notes (0.7.3 → 0.7.4)
- No schema change. Pin this gem at `0.7.4`. Hosts that linked the hub **New** or **All versions** actions should link **Edit Terms** and **Edit Privacy Policy** instead. The engine terms index now redirects to the versions screen. Hub **Live** and **Agrees** cards are **Terms and conditions** and **Privacy Policy**.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions/compare/v0.6.2...HEAD
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

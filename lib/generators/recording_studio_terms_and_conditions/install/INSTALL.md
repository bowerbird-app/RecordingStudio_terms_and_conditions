RecordingStudioTermsAndConditions install complete.

Next steps:

1. Review `config/initializers/recording_studio_terms_and_conditions.rb`.
2. The install generator copied this gem's migrations into `db/migrate`. Apply them with `bin/rails db:migrate`.
3. Register `RecordingStudioTermsAndConditions::Terms`, `Section`, and `Clause` (and Publishable's child type) in `RecordingStudio.configure { |c| c.recordable_types }`. Keep `recording_studio_recordable(...)` on every configured type. Add GitHub sources for `recording_studio_moveable` `v4.1.0` and `recording_studio_icons` `v0.2.0`.
4. Mount Publishable at `/` so the public page `/terms/:uuid/:slug` works. This gem also appends `/privacy/:uuid/:slug` for Privacy Policy rows. Edit sections and clauses, then Release. Release publishes through Publishable. The show-page Publish control still publishes the stored parent text.
5. Mount Admin, add an `AdminRoot`, enable `section :terms` (or `root_section: :terms`), and grant Accessible access to that root (`bootstrap_owner_access!` for the first staff member). Admin New picks Terms and Conditions or Privacy Policy. One lineage per kind per workspace. Sections belong to that one document.
6. The gem includes `ForcesAcceptance` on the host `ApplicationController` and prepends Users Auth `after_sign_in` / `after_sign_up` to the same Agree screen until every pending live kind is accepted (0..2). With Users `>= 0.12.1`, create-password shows `recording_studio_terms_continue_notice` and `accept!` each pending version with `{ "source" => "continue_notice" }` when that form succeeds. Do not add a second clickwrap. Drop `recording_studio_terms_agree` onto a host form (checkbox only); on submit call `accept!` for each pending live version. Or drop `recording_studio_terms_continue_notice` and call `accept!` with `{ "source" => "continue_notice" }` for each pending version. If you override default layout, skip PageNav when `content_for?(:skip_page_nav)` is set.
7. Pin `app/javascript/recording_studio_terms_and_conditions/controllers` in the host importmap (the install generator adds this when `config/importmap.rb` exists). The gem Agree screen does not apply scroll-to-end. Optional: wrap your own copy with `recording_studio_terms_scroll_to_end(require_scroll_to_end: true)` or set `config.require_scroll_to_end = true` on a host wrap. The checkbox is still required. If IntersectionObserver is missing, Agree stays enabled so people are not stuck. Optional: `config.capture_request_provenance = true` stores IP and user agent on gem UI accepts (default off).
8. Optional: mount Recording Studio API and include `RecordingStudio::Capabilities::TermsAndConditions.to` on the workspace type. The Terms type includes it. List `terms_pending_published_list`, `terms_current_published_for`, `terms_accepted`, and `terms_documents` on the workspace. List the outline, edit, preview, and release actions on `RecordingStudioTermsAndConditions::Terms`. Set `auto_capability_actions: false`. Grant the API client Accessible on the admin root. API clients may not accept Terms. The actor is the access grant's actor (`access_grant.actor`, the ApiClient under a client-credentials token). MCP uses `capability_action`.
9. For an existing database, run `ACTOR_TYPE=User ACTOR_ID=<staff id> bin/rails recording_studio_terms_and_conditions:seed_outline` after `db:migrate`. It does not publish and does not write receipts.
10. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.

Useful routes after mount:

- Agree: `/recording_studio_terms_and_conditions/acceptance` (mount path plus `/acceptance`)
- Admin hub: `/admin` (`New` parks on the Terms and Conditions section)
- Engine write form: `/recording_studio_terms_and_conditions/admin/terms`
- Public Terms: `/terms/:uuid/:slug`
- Public Privacy Policy: `/privacy/:uuid/:slug`

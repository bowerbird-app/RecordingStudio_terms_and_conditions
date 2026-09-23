RecordingStudioTermsAndConditions install complete.

Next steps:

1. Review `config/initializers/recording_studio_terms_and_conditions.rb`.
2. The install generator copied this gem's migrations into `db/migrate`. Apply them with `bin/rails db:migrate`.
3. Register `RecordingStudioTermsAndConditions::Terms` (and Publishable's child type) in `RecordingStudio.configure { |c| c.recordable_types }`. Keep `recording_studio_recordable(...)` on every configured type.
4. Mount Publishable at `/` so the public page `/terms/:uuid/:slug` works. This gem also appends `/privacy/:uuid/:slug` for Privacy Policy rows. Publish with Publishable `QuickActions` (or the Publish settings hub), not a custom publish action.
5. Mount Admin, add an `AdminRoot`, enable `section :terms` (or `root_section: :terms`), and grant Accessible access to that root (`bootstrap_owner_access!` for the first staff member). Admin New picks Terms and Conditions or Privacy Policy; one lineage per kind per workspace (further versions via edit/fork).
6. The gem includes `ForcesAcceptance` on the host `ApplicationController` and prepends Users Auth `after_sign_in` / `after_sign_up` to the same Agree screen until every pending live kind is accepted (0..2). With Users `>= 0.12.1`, create-password shows `recording_studio_terms_continue_notice` and `accept!` each pending version with `{ "source" => "continue_notice" }` when that form succeeds. Do not add a second clickwrap. Drop `recording_studio_terms_agree` onto a host form (checkbox only); on submit call `accept!` for each pending live version. Or drop `recording_studio_terms_continue_notice` and call `accept!` with `{ "source" => "continue_notice" }` for each pending version. If you override default layout, skip PageNav when `content_for?(:skip_page_nav)` is set.
7. Pin `app/javascript/recording_studio_terms_and_conditions/controllers` in the host importmap (the install generator adds this when `config/importmap.rb` exists). The gem Agree screen does not apply scroll-to-end. Optional: wrap your own copy with `recording_studio_terms_scroll_to_end(require_scroll_to_end: true)` or set `config.require_scroll_to_end = true` on a host wrap. The checkbox is still required. If IntersectionObserver is missing, Agree stays enabled so people are not stuck. Optional: `config.capture_request_provenance = true` stores IP and user agent on gem UI accepts (default off).
8. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.

Useful routes after mount:

- Agree: `/recording_studio_terms_and_conditions` (or your `--mount-path`)
- Admin hub: `/admin` (`New` parks on the Terms and Conditions section)
- Engine write form: `/recording_studio_terms_and_conditions/admin/terms`
- Public Terms: `/terms/:uuid/:slug`
- Public Privacy Policy: `/privacy/:uuid/:slug`

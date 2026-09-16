# frozen_string_literal: true

require "test_helper"

class RecordingStudioTermsAndConditionsTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.4.0", ::RecordingStudioTermsAndConditions::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioTermsAndConditions::Engine
  end

  def test_gemspec_pins_recording_studio_4_2
    gemspec = File.read(File.expand_path("../recording_studio_terms_and_conditions.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "flat_pack", ">= 0.1.183"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.8"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_admin", "~> 2.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_publishable", "~> 0.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_user", "~> 0.11"'
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_terms_and_conditions.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-terms-and-conditions", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_verified_4x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.2.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.11.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.183"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'tag: "v0.6.0"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20260911024811_add_depends_on_recording_id_to_recording_studio_accesses.rb",
        __dir__
      )
    )

    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, "index_recording_studio_accesses_on_depends_on_recording_id"
    assert_includes schema, 't.string "category", default: "terms", null: false'
    assert_includes schema, "index_rstac_terms_on_category"
    assert_includes migration, "add_column :recording_studio_accesses, :depends_on_recording_id, :uuid"
  end

  def test_template_does_not_ship_copied_core_hooks_or_base_service
    lib = File.expand_path("../lib/recording_studio_terms_and_conditions", __dir__)

    refute File.exist?(File.join(lib, "hooks.rb"))
    refute File.exist?(File.join(lib, "services/base_service.rb"))
    refute File.exist?(File.join(lib, "services/example_service.rb"))
  end

  def test_example_capability_wraps_include_for_and_is_not_enabled_globally
    source = File.read(
      File.expand_path("../lib/recording_studio_terms_and_conditions/capabilities/example.rb", __dir__)
    )

    assert_includes source, "def self.to(**)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:example, **)"
    refute_includes source, "enable_capability"
    refute_includes source, "set_capability_options"
    refute RecordingStudio.capability_enabled?(:example, for: "Folder")
    refute RecordingStudio.capability_enabled?(:example, for: "Page")
    assert_empty RecordingStudio.configuration.enabled_recordable_types_for(:example)
  end

  def test_terms_recordable_opts_into_publishable
    terms_source = File.read(File.expand_path("../app/models/recording_studio_terms_and_conditions/terms.rb", __dir__))
    acceptance_source = File.read(
      File.expand_path("../app/models/recording_studio_terms_and_conditions/acceptance.rb", __dir__)
    )

    assert_includes terms_source, 'label: "Terms"'
    assert_includes terms_source, 'self.table_name = "recording_studio_terms_and_conditions_terms"'
    assert_includes terms_source, 'DEFAULT_CATEGORY = "terms"'
    assert_includes terms_source, "category_unique_in_workspace"
    assert_includes terms_source, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes terms_source, 'public_controller: "recording_studio_terms_and_conditions/published_terms"'
    assert_includes terms_source, 'path: "/terms/:uuid/:slug"'
    refute_includes terms_source, "enable_capability"
    assert_includes acceptance_source, 'self.table_name = "recording_studio_terms_and_conditions_acceptances"'
    assert_includes acceptance_source, "def receipt_contract"
    assert_includes acceptance_source, "body_digest"
    refute_includes acceptance_source, "recording_studio_recordable"
  end

  def test_engine_keeps_product_migrations_and_drops_template_pages
    migrate_dir = File.expand_path("../db/migrate", __dir__)
    names = Dir.children(migrate_dir)

    refute_includes names, "20250101000001_create_recording_studio_terms_and_conditions_pages.rb"
    assert names.grep(/create_recording_studio_terms_and_conditions_terms/).any?
    assert names.grep(/create_recording_studio_terms_and_conditions_acceptances/).any?
    assert names.grep(/add_provenance_to_recording_studio_terms_and_conditions_acceptances/).any?
    assert names.grep(/add_body_digest_to_recording_studio_terms_and_conditions_acceptances/).any?
    create = File.read(File.join(migrate_dir, names.grep(/create_.*_acceptances/).first))
    provenance = File.read(File.join(migrate_dir, names.grep(/add_provenance_to_.*_acceptances/).first))
    unique = File.read(File.join(migrate_dir, names.grep(/unique_per_actor_and_version/).first))
    assert names.grep(/add_change_note_to_recording_studio_terms_and_conditions_terms/).any?
    assert names.grep(/add_category_to_recording_studio_terms_and_conditions_terms/).any?
    assert names.grep(/rename_kind_to_category_on_recording_studio_terms/).any?
    create_terms_name = names.grep(/create_recording_studio_terms_and_conditions_terms/).first
    create_terms = File.read(File.join(migrate_dir, create_terms_name))
    assert_includes create_terms, 't.string :category, null: false, default: "terms"'
    assert_includes create, "unique: true"
    assert_includes create, "index_rstac_acceptances_on_actor_and_version"
    refute_includes provenance, "index_rstac_acceptances_on_actor_and_version"
    assert_includes unique, "unique: true"
    assert_includes unique, "if_exists: true"
    refute_includes unique, "UPDATE"
    refute File.read(File.join(migrate_dir, names.grep(/body_digest/).first)).include?("UPDATE")
  end

  def test_module_exposes_terms_acceptance_helpers
    source = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions.rb", __dir__))

    assert_includes source, "def current_published_for(root, category: Terms::DEFAULT_CATEGORY)"
    assert_includes source, "def current_published_by_category(root)"
    assert_includes source, "def pending_published_for(actor, root, required_categories: nil)"
    assert_includes source, "def pending_published_list(actor, root, required_categories: nil)"
    assert_includes source, "def accepted?(actor, root, category: Terms::DEFAULT_CATEGORY)"
    assert_includes source, "def requires_acceptance?(actor, root, category: nil, required_categories: nil)"
    assert_includes source, "def reaccepting?(actor, root, category: nil, required_categories: nil)"
    assert_includes source, "class NotLive < StandardError"
    helpers = %i[
      current_published_for
      current_published_by_category
      pending_published_for
      pending_published_list
      accepted?
      requires_acceptance?
      accept!
      reaccepting?
    ]
    helpers.each do |helper|
      assert_includes RecordingStudioTermsAndConditions.singleton_methods, helper
    end
    assert_operator RecordingStudioTermsAndConditions::NotLive, :<, StandardError
    acceptance = File.read(
      File.expand_path("../lib/recording_studio_terms_and_conditions/terms_acceptance.rb", __dir__)
    )
    assert_includes acceptance, "currently_published?"
    assert_includes acceptance, "raise NotLive"
    assert_includes acceptance, "category:"
    assert_includes acceptance, "def current_published_by_category"
    assert_includes acceptance, "required_categories"
    assert File.exist?(engine_path("lib/recording_studio_terms_and_conditions/category_uniqueness.rb"))
    assert File.exist?(engine_path("lib/recording_studio_terms_and_conditions/category_coverage.rb"))
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "devise_controller? ? \"application\""
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/devise/sessions/new.html.erb", __dir__))

    dummy_routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    assert_includes dummy_routes, "recording_studio_user_auth_for :users"
    assert_includes dummy_routes, "skip: %i[sessions registrations passwords]"
    assert_includes dummy_routes, "mount RecordingStudioUser::Engine"

    agree_helper_page = File.read(File.expand_path("dummy/app/views/agree_helpers/show.html.erb", __dir__))
    assert_includes agree_helper_page, "FlatPack::CodeBlock::Component"
    refute_includes agree_helper_page, "Join"
    refute_includes agree_helper_page, "FlatPack::Button::Component"
  end

  def test_dummy_default_layout_head_loads_flatpack_application
    head = File.read(File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__))
    layout = File.read(File.expand_path("dummy/app/views/layouts/recording_studio/default_layout.html.erb", __dir__))

    assert_includes head, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes layout, 'stylesheet_link_tag "tailwind"'
    assert_includes layout, '<html data-theme="rounded">'
    assert_includes layout, "dummy_top_nav"
    assert_includes layout, "anchor_href"
    refute_includes layout, "page_nav_options[:back_url]"
    refute_includes layout, "page_nav_options[:anchor_url]"
    refute_includes layout, "url: back_url"
    refute_includes layout, "url: anchor_url"
    refute_includes layout, "max-w-3xl"
    assert layout.index('stylesheet_link_tag "flat_pack/application"') < layout.index('stylesheet_link_tag "tailwind"')

    helper = File.read(File.expand_path("dummy/app/helpers/application_helper.rb", __dir__))
    top_nav = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_top_nav.html.erb", __dir__))
    assert_includes helper, "def dummy_top_nav"
    refute_includes helper, "url: main_app.destroy_user_session_path"
    assert_includes top_nav, "FlatPack::TopNav::Component"
    assert_includes top_nav, 'href: "/users/sign_out"'
    assert_includes top_nav, "method: :delete"
  end

  def test_agree_and_admin_views_skip_card_wrappers_and_echoed_tick_copy
    views = "app/views/recording_studio_terms_and_conditions"
    agree = engine_source("#{views}/acceptances/show.html.erb")
    admin_index = engine_source("#{views}/admin/terms/index.html.erb")
    admin_show = engine_source("#{views}/admin/terms/show.html.erb")
    admin_new = engine_source("#{views}/admin/terms/new.html.erb")
    public_show = engine_source("#{views}/published_terms/show.html.erb")
    controller = engine_source(
      "app/controllers/recording_studio_terms_and_conditions/application_controller.rb"
    )
    terms_model = engine_source("app/models/recording_studio_terms_and_conditions/terms.rb")

    assert_includes controller, 'layout "recording_studio/default_layout"'
    assert_includes terms_model, 'public_layout: "recording_studio/default_layout"'
    refute File.exist?(engine_path("app/views/layouts/recording_studio_terms_and_conditions/public.html.erb"))

    refute_includes agree, "FlatPack::Card::Component"
    assert_includes agree, "inside_form: true"
    assert_includes agree, "pending: @pending_terms"
    assert_includes agree, "terms_agree_heading"
    assert_includes agree, "FlatPack::SectionTitle::Component"
    assert_includes agree, "terms_version_date"
    assert_includes agree, "terms_content"
    assert_includes agree, "-mt-5 mb-6"
    helper = engine_source("app/helpers/recording_studio_terms_and_conditions/agree_helper.rb")
    scroll_helper = engine_source("app/helpers/recording_studio_terms_and_conditions/scroll_to_end_helper.rb")
    assert_includes helper, "include ScrollToEndHelper"
    assert_includes helper, "def recording_studio_terms_agree"
    assert_includes helper, "pending: nil"
    assert_includes helper, "recording_studio_terms_agree_label"
    copy_helper = engine_source("app/helpers/recording_studio_terms_and_conditions/agree_copy_helper.rb")
    assert_includes copy_helper, "def terms_agree_heading"
    assert_includes copy_helper, "def terms_users_subtitle"
    assert_includes helper, "requires_acceptance?"
    assert_includes helper, "link_terms: false"
    assert_includes scroll_helper, "def recording_studio_terms_scroll_to_end"
    assert_includes scroll_helper, "def recording_studio_terms_agree_button"
    assert_includes scroll_helper, "require_scroll_to_end"
    controller_js = engine_source(
      "app/javascript/recording_studio_terms_and_conditions/controllers/scroll_to_end_controller.js"
    )
    assert_includes controller_js, "shouldLockAgree"
    assert_includes controller_js, "IntersectionObserver"
    assert_includes helper, "class: \"py-5\""
    assert_includes helper, "with_content(\"terms\")"
    refute_includes helper, "Read the full terms"
    refute_includes helper, "form_with"
    application_helper = engine_source("app/helpers/recording_studio_terms_and_conditions/application_helper.rb")
    assert_includes application_helper, "include TablePaginationHelper"
    pagination_helper = engine_source(
      "app/helpers/recording_studio_terms_and_conditions/table_pagination_helper.rb"
    )
    assert_includes pagination_helper, "def terms_table_pagination"
    assert_includes pagination_helper, "FlatPack::Pagination::Component"
    base_controller = engine_source(
      "app/controllers/recording_studio_terms_and_conditions/admin/base_controller.rb"
    )
    assert_includes base_controller, "include ::Pagy::Backend"
    table_page = engine_source("lib/recording_studio_terms_and_conditions/table_page.rb")
    assert_includes table_page, "SIZE = 25"
    assert_includes table_page, "def paginate_table"
    assert_includes table_page, "overflow: :last_page"
    assert_includes application_helper, "def terms_calendar_date"
    assert_includes application_helper, "%e %b %Y"
    assert_includes application_helper, "def terms_content"
    assert_includes application_helper, "def terms_admin_hub_path"
    assert_includes application_helper, "flat-pack-content-editor-content"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/engine.rb"),
                    "helper RecordingStudioTermsAndConditions::ApplicationHelper"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/engine.rb"),
                    "CategoryUniqueness.install!"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/gate.rb"), "agree_helpers"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/gate.rb"), "pending_published_list"
    refute_includes agree, "help_text"
    refute_includes agree, "Read them, tick the box"
    assert_includes agree, "FlatPack::Alert::Component"
    assert_includes agree, "@reaccepting"
    assert_includes agree, "terms_reaccept_notice"
    refute_includes public_show, "FlatPack::Card::Component"
    refute_includes public_show, "<article>"
    assert_includes public_show, "terms_content"
    assert_includes public_show, "terms_version_date"
    assert_includes public_show, "-mt-5 mb-6"
    assert_includes admin_index, "page_title.slot"
    assert_includes admin_index, 'title: "Published"'
    assert_includes admin_index, 'title: "Category"'
    assert_includes admin_index, 'title: "Coverage"'
    assert_includes admin_index, 'name: "category"'
    assert_includes admin_index, "category_select_options"
    assert_includes admin_index, "terms_admin_hub_path"
    assert_includes admin_show, "page_title.slot"
    assert_includes admin_show, "terms_content"
    assert_includes admin_show, 'text: "Users"'
    assert_includes admin_show, "admin_term_users_path"
    refute_includes admin_show, "Who agreed"
    assert_includes admin_show, "Recording"
    assert_includes admin_show, "snapshot"
    users = engine_source("#{views}/admin/term_users/index.html.erb")
    assert_includes users, 'title: "Users"'
    assert_includes users, "terms_users_subtitle"
    assert_includes users, "Nobody yet"
    assert_includes users, "terms_table_pagination"
    assert_includes engine_source("config/routes.rb"), 'controller: "term_users"'
    refute_includes admin_new, "FlatPack::Card::Component"
    refute_includes admin_new, "card.footer"
    assert_includes admin_new, 'class="inline-block"'
    assert_includes admin_new, "terms_admin_hub_path"
    refute_includes engine_source("#{views}/admin/terms/edit.html.erb"), "FlatPack::Card::Component"
    assert_includes engine_source("#{views}/admin/terms/edit.html.erb"), 'class="inline-block"'
    refute_includes admin_show, "FlatPack::Card::Component"
    assert_includes admin_index, "FlatPack::Table::Component"
    assert_includes admin_index, "terms_table_pagination"
    assert_includes admin_index, "terms_rows"
    assert_includes admin_index, 'title: "Open"'
    refute_includes admin_index, "min_width: :lg"
    form = engine_source("#{views}/admin/terms/_form.html.erb")
    assert_includes form, "terms_body_editor"
    assert_includes form, "FlatPack::Select::Component"
    assert_includes form, "terms[category]"
    assert_includes form, "category_select_options"
    assert_includes form, "gap-6"
    assert_includes form, "flat-pack-input-wrapper]:border-0"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/sample_terms.rb"), "Using the booth"
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))
    assert_includes importmap, "@tiptap/core"
    assert_includes importmap, "flat_pack/tiptap"
    assert_includes importmap, "recording_studio_terms_and_conditions/controllers"
    assert_includes importmap, "File.expand_path"
    assert_includes importmap, 'pin "@hotwired/turbo-rails", to: "turbo.min.js"'
    application_js = File.read(File.expand_path("dummy/app/javascript/application.js", __dir__))
    assert_includes application_js, 'import "@hotwired/turbo-rails"'
    accept = engine_source("#{views}/acceptances/show.html.erb")
    assert_includes accept, "recording_studio_terms_scroll_to_end"
    assert_includes accept, "recording_studio_terms_agree_button"
    controller_js = "app/javascript/recording_studio_terms_and_conditions/controllers/scroll_to_end_controller.js"
    assert File.exist?(engine_path(controller_js))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "flatpack-*/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "usr/local/lib/ruby/gems/**/bundler/gems/flatpack-"
    assert_includes tailwind_source, "../../../vendor/bundle/**/recording_studio/app/views/**/*.erb"
    assert_includes tailwind_source, "recordingstudio-*/app/views/**/*.erb"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, "AdminRoot"
    assert_includes initializer_source, "RecordingStudioTermsAndConditions::Terms"
    assert_includes initializer_source, "RecordingStudioUser::People"
    assert_includes initializer_source, "RecordingStudioPublishable::Publishable"
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to validate the Recording Studio Terms and Conditions addon"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "redirects to `/`"
    refute_includes readme_source, "flat_pack_sidebar"
  end

  def test_product_readme_is_the_addon_guide
    readme = File.read(File.expand_path("../README.md", __dir__))

    internals_docs = File.join("docs", %w[gem template].join("_"))
    old_module = %w[Gem Template].join

    assert_includes readme, "RecordingStudio"
    assert_includes readme, "recording_studio_terms_and_conditions"
    assert_includes readme, "RecordingStudioTermsAndConditions"
    assert_includes readme, "https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions"
    assert_includes readme, "recording-studio-gems"
    assert_includes readme, "require_scroll_to_end"
    assert_includes readme, "Upgrading from 0.3.x"
    assert_includes readme, "pending_published_list"
    assert_includes readme, "MIGRATION_NOTES.md"
    refute_includes readme, "come later"
    assert_includes readme, "#{internals_docs}/"
    assert_includes readme, "v4.2.0"
    assert_includes readme, "v0.1.183"
    assert_includes readme, "v0.9.1"
    refute_includes readme, "Internal template"
    refute_includes readme, old_module
    refute_includes readme, "v0.1.133"
    refute_includes readme, "v3 declarations"
    refute_includes readme, "RecordingStudio v3"
    refute_includes readme, "ExampleService"
    refute_includes readme, "recording_studio/v3.0.0"
  end

  def test_product_gemspec_points_at_this_repo
    gemspec = File.read(File.expand_path("../recording_studio_terms_and_conditions.gemspec", __dir__))
    template_repo = "RecordingStudio_#{%w[gem template].join('_')}"

    assert_includes gemspec, 'spec.name        = "recording_studio_terms_and_conditions"'
    assert_includes gemspec, "https://github.com/bowerbird-app/RecordingStudio_terms_and_conditions"
    refute_includes gemspec, "internal template"
    refute_includes gemspec, "addon template for Rails engines"
    refute_includes gemspec, template_repo
    refute_includes gemspec, "https://github.com/bowerbird-app/recording_studio_terms_and_conditions"
    refute_includes gemspec, "come later"
    assert_includes gemspec, "clickwrap Agree screen"
    assert_includes gemspec, "Publishable public URL"
  end

  def test_dummy_home_page_uses_demo_title_only
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, 'title: "Terms demo"'
    assert_includes view_source, 'subtitle: "This dummy app is the browser-facing demo surface for the addon."'
    assert_includes view_source, 'text: "Write terms"'
    assert_includes view_source, "dummy_admin_hub_switch_href"
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "dummy_page_nav"
    refute_includes view_source, 'title: "Demo"'
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav"
      assert_includes view_source, "FlatPack::PageTitle::Component"
      refute_includes view_source, "FlatPack::Card::Component"
      refute_includes view_source, "FlatPack::Breadcrumb::Component"
    end

    methods_view = File.read(File.expand_path("dummy/app/views/docs/methods.html.erb", __dir__))
    assert_includes methods_view, "FlatPack::SectionTitle::Component"
    assert_includes methods_view, "FlatPack::CodeBlock::Component"

    gem_views_view = File.read(File.expand_path("dummy/app/views/docs/gem_views.html.erb", __dir__))
    assert_includes gem_views_view, "FlatPack::Table::Component"
    assert_includes gem_views_view, "FlatPack::Pagination::Component"
    refute_includes gem_views_view, "FlatPack::List::Component"

    recordable_types_view = File.read(File.expand_path("dummy/app/views/docs/recordable_types.html.erb", __dir__))
    assert_includes recordable_types_view, "FlatPack::List::Component"
    refute_includes recordable_types_view, "v3 parent/root"

    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_dummy_recordings_tree_view_omits_structure_section_copy
    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))

    assert_includes recordings_tree_view, 'title: "Recordings tree"'
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    recording_tree_partial = File.read(File.expand_path("dummy/app/views/docs/_recording_tree_node.html.erb", __dir__))
    assert_includes recording_tree_partial, "parent_builder.node"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_engine_ships_clickwrap_and_admin_views
    engine_root = File.expand_path("..", __dir__)

    views = "app/views/recording_studio_terms_and_conditions"
    assert File.exist?(File.join(engine_root, views, "acceptances/show.html.erb"))
    assert File.exist?(File.join(engine_root, views, "admin/terms/index.html.erb"))
    assert File.exist?(File.join(engine_root, views, "admin/term_users/index.html.erb"))
    assert File.exist?(File.join(engine_root, views, "published_terms/show.html.erb"))
    routes = File.read(File.join(engine_root, "config/routes.rb"))
    assert_includes routes, "resource :acceptance"
    assert_includes routes, "resources :terms"
    admin = File.read(File.join(engine_root, "lib/recording_studio_terms_and_conditions/admin.rb"))
    assert_includes admin, 'key "terms"'
    assert_includes admin, "paginate per_page: 25"
    assert_includes admin, 'text: "Every version"'
    assert_includes admin, 'widget "widgets.terms.live", view_variant: :card'
    assert_includes admin, 'widget "widgets.terms.agrees", view_variant: :card'
    refute_includes admin, "view_variant: :compact"
    assert File.exist?(engine_path("lib/recording_studio_terms_and_conditions/admin_widget_card.rb"))
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/engine.rb"),
                    "AdminWidgetCard"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/engine.rb"),
                    "FlatpackButtonHrefFromUrl"
    assert File.exist?(engine_path("lib/recording_studio_terms_and_conditions/flatpack_button_href_from_url.rb"))
    assert_includes admin, 'admin_screen_path("recording_studio_terms")'
    assert_includes admin, "column :published"
    assert_includes admin, "column :category"
    assert_includes admin, "category_label"
    assert_includes admin, "admin_write_path"
    assert_includes admin, "admin_hub_path"
    dummy_routes = File.read(File.join(engine_root, "test/dummy/config/routes.rb"))
    assert_includes dummy_routes, "mount RecordingStudioTermsAndConditions::Engine"
    assert_includes dummy_routes, "mount RecordingStudioPublishable::Engine"
    assert_includes dummy_routes, "recording_studio_admin_for :admin"
    assert File.exist?(File.join(engine_root, "lib/recording_studio_terms_and_conditions/gate.rb"))
    assert File.exist?(File.join(engine_root, "lib/recording_studio_terms_and_conditions/forces_acceptance.rb"))
    assert File.exist?(File.join(engine_root, "lib/recording_studio_terms_and_conditions/users_auth_redirect.rb"))
    assert File.exist?(File.join(engine_root, "lib/recording_studio_terms_and_conditions/acceptance_gate_installer.rb"))
    skill = File.join(engine_root, ".github/skills/recording-studio-terms-and-conditions/SKILL.md")
    assert File.exist?(skill)
    assert_includes File.read(skill), "recording-studio-gems"
    assert_includes File.read(skill), "Upgrade (0.3.x → 0.4.0)"
  end

  def test_zero_four_upgrade_docs_match_shipped_behavior
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))
    notes = File.read(File.expand_path("../MIGRATION_NOTES.md", __dir__))
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes changelog, "## [0.4.0]"
    assert_includes changelog, "Upgrade notes (0.3.x → 0.4.0)"
    assert_includes changelog, "body_digest"
    assert_includes changelog, "NotLive"
    assert_includes changelog, "terms`, `privacy`, `usage"
    assert_includes changelog, "required_categories"
    assert_includes changelog, "api_key"
    assert_includes notes, "Upgrade from 0.3.x to 0.4.0"
    assert_includes notes, "change_note"
    assert_includes notes, "pending_published_list"
    assert_includes readme, "Upgrading from 0.3.x"
    refute_includes changelog, "enable_feature_x = true"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_terms_and_conditions/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end

  private

  def engine_path(relative)
    File.expand_path(File.join("..", relative), __dir__)
  end

  def engine_source(relative)
    File.read(engine_path(relative))
  end
end

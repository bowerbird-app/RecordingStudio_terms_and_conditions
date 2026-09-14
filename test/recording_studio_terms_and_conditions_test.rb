# frozen_string_literal: true

require "test_helper"

class RecordingStudioTermsAndConditionsTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.3.0", ::RecordingStudioTermsAndConditions::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioTermsAndConditions::Engine
  end

  def test_gemspec_pins_recording_studio_4_2
    gemspec = File.read(File.expand_path("../recording_studio_terms_and_conditions.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "flat_pack", ">= 0.1.144"'
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
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.177"'
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
    assert_includes terms_source, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes terms_source, 'public_controller: "recording_studio_terms_and_conditions/published_terms"'
    assert_includes terms_source, 'path: "/terms/:uuid/:slug"'
    refute_includes terms_source, "enable_capability"
    assert_includes acceptance_source, 'self.table_name = "recording_studio_terms_and_conditions_acceptances"'
    refute_includes acceptance_source, "recording_studio_recordable"
  end

  def test_module_exposes_terms_acceptance_helpers
    source = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions.rb", __dir__))

    assert_includes source, "def current_published_for(root)"
    assert_includes source, "def accepted?(actor, root)"
    assert_includes source, "def requires_acceptance?(actor, root)"
    assert_includes source, "def accept!(actor, version, provenance = {})"
    %i[current_published_for accepted? requires_acceptance? accept!].each do |helper|
      assert_includes RecordingStudioTermsAndConditions.singleton_methods, helper
    end
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
    assert_includes top_nav, "href: main_app.destroy_user_session_path"
    assert_includes top_nav, "method: :delete"
  end

  def test_agree_and_admin_views_use_cards_and_skip_echoed_tick_copy
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

    assert_includes agree, "FlatPack::Card::Component"
    assert_includes agree, "recording_studio_terms_agree(inside_form: true"
    assert_includes engine_source("app/helpers/recording_studio_terms_and_conditions/agree_helper.rb"),
                    "def recording_studio_terms_agree"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/engine.rb"),
                    "helper RecordingStudioTermsAndConditions::ApplicationHelper"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/gate.rb"), "agree_helpers"
    refute_includes agree, "help_text"
    refute_includes agree, "Read them, tick the box"
    refute_includes agree, "FlatPack::Alert::Component"
    assert_includes public_show, "FlatPack::Card::Component"
    refute_includes public_show, "<article>"
    assert_includes admin_index, "page_title.slot"
    assert_includes admin_show, "page_title.slot"
    assert_includes admin_new, "FlatPack::Card::Component"
    assert_includes admin_new, "card.footer"
    assert_includes admin_index, "FlatPack::Table::Component"
    assert_includes admin_index, "terms_rows"
    assert_includes admin_index, 'title: "Open"'
    refute_includes admin_index, "min_width: :lg"
    assert_includes engine_source("#{views}/admin/terms/_form.html.erb"), "terms_body_editor"
    assert_includes engine_source("lib/recording_studio_terms_and_conditions/sample_terms.rb"), "Using the booth"
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))
    assert_includes importmap, "@tiptap/core"
    assert_includes importmap, "flat_pack/tiptap"
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
    assert_includes readme, "#{internals_docs}/"
    assert_includes readme, "v4.2.0"
    assert_includes readme, "v0.1.177"
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
  end

  def test_dummy_home_page_uses_demo_title_only
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, 'title: "Terms demo"'
    assert_includes view_source, 'subtitle: "This dummy app is the browser-facing demo surface for the addon."'
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
    assert File.exist?(File.join(engine_root, views, "published_terms/show.html.erb"))
    routes = File.read(File.join(engine_root, "config/routes.rb"))
    assert_includes routes, "resource :acceptance"
    assert_includes routes, "resources :terms"
    admin = File.read(File.join(engine_root, "lib/recording_studio_terms_and_conditions/admin.rb"))
    assert_includes admin, 'key "terms"'
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

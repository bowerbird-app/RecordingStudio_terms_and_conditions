# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_terms_and_conditions/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_terms_and_conditions/install/templates/INSTALL.md",
    __dir__
  )

  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/assets/tailwind"))
      yield dir
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioTermsAndConditions::Generators::InstallGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_install_migrations_invokes_migrations_generator
    generator = build_generator("/tmp")
    commands = []

    generator.stub(:generate, ->(command) { commands << command }) do
      generator.install_migrations
    end

    assert_equal ["recording_studio_terms_and_conditions:migrations"], commands
  end

  def test_install_migrations_can_be_skipped
    generator = build_generator("/tmp", skip_migrations: true)
    commands = []

    generator.stub(:generate, ->(command) { commands << command }) do
      generator.install_migrations
    end

    assert_empty commands
  end

  def test_mount_engine_skips_when_already_mounted
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/routes.rb"), <<~RUBY)
        Rails.application.routes.draw do
          mount RecordingStudioTermsAndConditions::Engine, at: "/recording_studio_terms_and_conditions"
        end
      RUBY

      generator = build_generator(dir)
      routes = []
      messages = []

      generator.stub(:route, ->(value) { routes << value }) do
        generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
          generator.mount_engine
        end
      end

      assert_empty routes
      assert_includes messages, ["RecordingStudioTermsAndConditions is already mounted.", :green]
    end
  end

  def test_mount_engine_uses_configured_mount_path
    generator = build_generator("/tmp", mount_path: "/addons/recording")
    routes = []

    generator.stub(:route, ->(value) { routes << value }) do
      generator.mount_engine
    end

    assert_equal ["mount RecordingStudioTermsAndConditions::Engine, at: \"/addons/recording\""], routes
  end

  def test_add_tailwind_source_injects_engine_and_flatpack_sources
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@import \"tailwindcss\";\n")

      generator = build_generator(dir)

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, nil) do
          generator.add_tailwind_source
        end
      end

      css = File.read(css_path)
      assert_tailwind_sources_present(css)
    end
  end

  def test_add_tailwind_source_does_not_duplicate_existing_entries
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, <<~CSS)
        @import "tailwindcss";
        @source "../../vendor/bundle/**/recording_studio_terms_and_conditions/app/views/**/*.erb";
        @source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/recording_studio_terms_and_conditions-*/app/views/**/*.erb";
        @source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";
        @source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";
      CSS

      generator = build_generator(dir)

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, nil) do
          generator.add_tailwind_source
        end
      end

      css = File.read(css_path)
      assert_tailwind_sources_present(css)
      assert_tailwind_sources_count(css, 1)
    end
  end

  def test_add_tailwind_source_reports_missing_tailwind_config
    with_temp_app do |dir|
      FileUtils.rm_rf(File.join(dir, "app/assets/tailwind"))
      generator = build_generator(dir)
      messages = []

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
          generator.add_tailwind_source
        end
      end

      assert_includes messages, ["Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow]
      assert_includes messages, ["If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow]
      tailwind_source_lines.each do |line|
        assert_includes messages, ["  #{line}", :yellow]
      end
    end
  end

  def test_add_tailwind_source_reports_manual_configuration_when_import_is_missing
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@source \"../local/**/*.erb\";\n")
      generator = build_generator(dir)
      messages = []

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
          generator.add_tailwind_source
        end
      end

      assert_equal "@source \"../local/**/*.erb\";\n", File.read(css_path)
      assert_includes messages, ["Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow]
      assert_includes messages, ["Please manually add these lines to your Tailwind CSS config:", :yellow]
      tailwind_source_lines.each do |line|
        assert_includes messages, ["  #{line}", :yellow]
      end
    end
  end

  def test_show_readme_displays_install_guide_for_invoke_behavior
    generator = build_generator("/tmp")
    shown_templates = []

    generator.stub(:behavior, :invoke) do
      generator.stub(:readme, ->(template) { shown_templates << template }) do
        generator.show_readme
      end
    end

    assert_equal ["INSTALL.md"], shown_templates
  end

  def test_install_guide_includes_migration_and_host_setup_steps
    install_guide = File.read(INSTALL_TEMPLATE_PATH)
    initializer = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_terms_and_conditions/install/templates/" \
        "recording_studio_terms_and_conditions_initializer.rb",
        __dir__
      )
    )

    assert_includes install_guide, "bin/rails db:migrate"
    assert_includes install_guide, "copied this gem's migrations"
    assert_includes install_guide, "RecordingStudioTermsAndConditions::Terms"
    assert_includes install_guide, "section :terms"
    assert_includes install_guide, "ForcesAcceptance"
    assert_includes install_guide, "/terms/:uuid/:slug"
    assert_includes install_guide, "require_scroll_to_end"
    assert_includes install_guide, "importmap"
    assert_includes initializer, "config.mount_path"
    assert_includes initializer, "require_scroll_to_end"
    assert_includes initializer, "capture_request_provenance"
    refute_includes initializer, "enable_feature_x"
    refute_includes initializer, "api_key"
    refute_includes initializer, "config.timeout"
    refute_includes install_guide, "RecordingStudio v3"
  end

  def test_add_importmap_pin_appends_scroll_controller
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/importmap.rb"), "pin \"application\"\n")
      generator = build_generator(dir)

      generator.stub(:say, nil) do
        generator.add_importmap_pin
      end

      importmap = File.read(File.join(dir, "config/importmap.rb"))
      assert_includes importmap, "recording_studio_terms_and_conditions/controllers"
      assert_includes importmap, "controllers/recording_studio_terms_and_conditions"
    end
  end

  def test_add_importmap_pin_skips_when_already_present
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(
        File.join(dir, "config/importmap.rb"),
        "pin_all_from RecordingStudioTermsAndConditions::Engine.root.join(" \
        "\"app/javascript/recording_studio_terms_and_conditions/controllers\")\n"
      )
      generator = build_generator(dir)
      messages = []

      generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
        generator.add_importmap_pin
      end

      assert_includes messages, ["Importmap already pins the scroll-to-end controller.", :green]
      pin_mentions = File.read(File.join(dir, "config/importmap.rb"))
                         .scan("recording_studio_terms_and_conditions/controllers")
      assert_equal 1, pin_mentions.size
    end
  end

  def test_kit_skill_lists_this_gem
    skill = File.read(
      File.expand_path("../.github/skills/recording-studio-terms-and-conditions/SKILL.md", __dir__)
    )

    assert_includes skill, "name: recording-studio-terms-and-conditions"
    assert_includes skill, "recording_studio_terms_and_conditions"
    assert_includes skill, "recording-studio-gems"
    assert_includes skill, "ForcesAcceptance"
  end

  private

  def assert_tailwind_sources_present(css)
    tailwind_source_lines.each do |line|
      assert_includes css, line
    end
  end

  def assert_tailwind_sources_count(css, count)
    tailwind_source_lines.each do |line|
      assert_equal count, css.scan(line).size
    end
  end

  def tailwind_source_lines
    [
      '@source "../../vendor/bundle/**/recording_studio_terms_and_conditions/app/views/**/*.erb";',
      '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/' \
      'recording_studio_terms_and_conditions-*/app/views/**/*.erb";',
      '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
      '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";',
      '@source "../../../../../../usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
    ]
  end
end

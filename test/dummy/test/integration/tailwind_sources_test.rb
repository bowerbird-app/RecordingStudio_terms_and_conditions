# frozen_string_literal: true

require "test_helper"

class TailwindSourcesTest < ActiveSupport::TestCase
  test "tailwind links Bundler gem directories and the build includes collapse utilities" do
    source = Rails.root.join("app/assets/tailwind/application.css").read

    assert_includes source, '@import "./bundled_sources.css"'
    refute_includes source, "/usr/local"
    refute_includes source, "hostedtoolcache"

    require "rake"
    Rails.application.load_tasks unless Rake::Task.task_defined?("tailwindcss:link_engine_sources")
    Rake::Task["tailwindcss:link_engine_sources"].reenable
    Rake::Task["tailwindcss:link_engine_sources"].invoke

    link = Rails.root.join("vendor/engines/flat_pack")
    assert link.symlink?
    assert_equal Pathname.new(Gem.loaded_specs.fetch("flat_pack").full_gem_path).realpath, link.realpath

    generated = Rails.root.join("app/assets/tailwind/bundled_sources.css").read
    assert_includes generated, '@source "../../../vendor/engines/flat_pack/app/components"'
    assert_includes generated, '@source "../../../vendor/engines/recording_studio/app/views"'
    refute_includes generated, "/usr/local"

    built = Rails.root.join("app/assets/builds/tailwind.css").read
    assert_includes built, "collapse-trigger-padding"
    assert_includes built, "collapse-border-radius"
    assert_includes built, "collapse-trigger-background-color"
  end
end

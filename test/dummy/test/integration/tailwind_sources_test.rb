# frozen_string_literal: true

require "test_helper"

class TailwindSourcesTest < ActiveSupport::TestCase
  test "tailwind sources are absolute and the build includes collapse utilities" do
    source = Rails.root.join("app/assets/tailwind/application.css").read

    assert_includes source, "/usr/local/lib/ruby/gems/*/bundler/gems/flatpack-*/app/components"
    assert_includes source, "/opt/hostedtoolcache/Ruby/*/x64/lib/ruby/gems/*/bundler/gems/flatpack-*/app/components"
    refute_includes source, "../../../../../../usr/local"

    built = Rails.root.join("app/assets/builds/tailwind.css").read
    assert_includes built, "collapse-trigger-padding"
    assert_includes built, "collapse-border-radius"
    assert_includes built, "collapse-trigger-background-color"
  end
end

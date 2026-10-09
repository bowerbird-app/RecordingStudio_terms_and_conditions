# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_terms_and_conditions.gemspec
gemspec

# Kit gems are not published to RubyGems; resolve gemspec pins from GitHub.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.213"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.13.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.1.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.13.0"
gem "recording_studio_publishable", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.6.0"
gem "recording_studio_user", github: "bowerbird-app/RecordingStudio_users", tag: "v0.16.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end

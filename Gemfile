# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_terms_and_conditions.gemspec
gemspec

# Kit gems are not published to RubyGems; resolve gemspec pins from GitHub.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.357"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.7.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.32.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.13.0"
# Publishable 0.15 and Attachable 0.23 depend on API. Not a gemspec dependency of this gem.
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.23.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.23.0"
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.3"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.2.1"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.4"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.8.0"
gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v4.1.1"
gem "recording_studio_publishable", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.15.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.14.0",
                                  require: false
gem "recording_studio_user", github: "bowerbird-app/RecordingStudio_users", tag: "v0.28.1"

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

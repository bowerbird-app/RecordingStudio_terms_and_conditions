> **Architecture Documentation**
> *   **Canonical Source:** [bowerbird-app/gem_template](https://github.com/bowerbird-app/gem_template/tree/main/docs/gem_template)
> *   **Last Updated:** September 21, 2026
>
> *Maintainers: Please update the date above when modifying this file.*

---

# GemTemplate Configuration

This document explains how to configure **GemTemplate** in your host Rails application.

---

## Quick Start

After installing the gem, run the install generator:

```bash
rails generate gem_template:install
```

This will:

1. Mount the engine in your routes (`/gem_template` by default).
2. Create `config/initializers/gem_template.rb` with example settings.
3. Optionally create `config/gem_template.yml` for environment-specific configuration.

---

## Configuration Options

This addon does not ship template knobs (`api_key`, `enable_feature_x`, `timeout`). Product settings:

| Option                        | Type    | Default                                      | Description |
|-------------------------------|---------|----------------------------------------------|-------------|
| `mount_path`                  | String  | `/recording_studio_terms_and_conditions`     | Engine mount used by Agree and admin path helpers. |
| `app_name`                    | String  | `""`                                         | Product name. When blank, uses `RecordingStudioSiteSettings.name_for` if that method exists. Site Settings is not required. |
| `require_scroll_to_end`       | Boolean | `false`                                      | When true, Agree starts disabled until the live copy sentinel is visible. Missing `IntersectionObserver` leaves Agree enabled. The checkbox is still required. |
| `capture_request_provenance`  | Boolean | `false`                                      | When true, the gem Agree screen stores IP and user agent on new receipts. Direct `accept!` callers pass their own provenance. Default stays off. |

### RecordingStudio Host-App Declarations

The dummy host app pins RecordingStudio to GitHub tag `v4.2.0` (`~> 4.2` in the gemspec) and keeps strict recordable declarations enabled:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = ["Workspace", "Folder", "Page"]
  config.require_recordable_declarations = true
end

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
end

class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", root: false, allowed_parent_types: ["Workspace", "Folder"]
end
```

Use `RecordingStudio.validate_recordable_declarations!`, `RecordingStudio.root_recordable_types`, and
`RecordingStudio.allowed_parent_types_for("Page")` to verify the host app wiring.

---

## Configuration Methods

### 1. Ruby Initializer (Recommended)

Edit `config/initializers/gem_template.rb`:

```ruby
RecordingStudioTermsAndConditions.configure do |config|
  config.mount_path = "/recording_studio_terms_and_conditions"
  config.app_name = "Your app"
  config.require_scroll_to_end = false
  config.capture_request_provenance = false
end
```

This approach is flexible and allows dynamic values, environment variables, and Rails credentials.

### 2. YAML Configuration

If you prefer environment-specific static settings, create `config/gem_template.yml`:

```yaml
development:
  mount_path: "/recording_studio_terms_and_conditions"
  require_scroll_to_end: false

production:
  mount_path: "/recording_studio_terms_and_conditions"
  require_scroll_to_end: false
```

The engine loads this file automatically via `Rails.application.config_for(:gem_template)`.

### 3. `config.x` Namespace

You can also set values in `config/application.rb` or environment files:

```ruby
# config/environments/production.rb
config.x.recording_studio_terms_and_conditions.mount_path = "/recording_studio_terms_and_conditions"
config.x.recording_studio_terms_and_conditions.require_scroll_to_end = false
```

---

## Load Order & Precedence

Configuration is merged in the following order (later sources override earlier ones):

1. **Defaults** – defined in `GemTemplate::Configuration#initialize`.
2. **YAML** – `config/gem_template.yml` loaded via `config_for`.
3. **`config.x.gem_template`** – values set in Rails config files.
4. **Initializer** – `GemTemplate.configure` block in `config/initializers/gem_template.rb`.

> **Tip:** For most use cases, stick with the Ruby initializer and use environment variables for secrets.

---

## Accessing Configuration at Runtime

```ruby
RecordingStudioTermsAndConditions.configuration.mount_path
# => "/recording_studio_terms_and_conditions"

RecordingStudioTermsAndConditions.configuration.app_name
# => "Your app"

RecordingStudioTermsAndConditions.configuration.require_scroll_to_end
# => false

RecordingStudioTermsAndConditions.configuration.to_h
# => { mount_path: "...", app_name: "...", require_scroll_to_end: false, capture_request_provenance: false, ... }
```

You can access these values from anywhere in your application or from within the engine's controllers, models, and jobs.

---

## Secret Management

This addon has no API key. If you turn on `capture_request_provenance`, treat IP and user agent as personal data in your host retention policy. Keep the flag off unless you need it.

---

## Extending Configuration

To add new options:

1. Add `attr_accessor` in `lib/gem_template/configuration.rb`.
2. Set a sensible default in `#initialize`.
3. Update `#to_h` if you want the option included in hash export.
4. Document the new option in this file and in the initializer template.

---

## Troubleshooting

| Issue                                  | Solution                                                                 |
|----------------------------------------|--------------------------------------------------------------------------|
| YAML not loading                       | Ensure `config/gem_template.yml` exists and has valid YAML syntax.       |
| Initializer values not applied         | Make sure the initializer runs after the engine initializer (default).   |
| `config.x` values ignored              | Verify you're setting them in the correct environment file.             |

---

## Files Reference

| File                                                        | Purpose                                      |
|-------------------------------------------------------------|----------------------------------------------|
| `lib/gem_template/configuration.rb`                         | Configuration class with defaults.           |
| `lib/gem_template/engine.rb`                                | Engine initializer that loads host config.   |
| `lib/generators/gem_template/install/install_generator.rb`  | Install generator that creates config files. |
| `lib/generators/gem_template/install/templates/`            | Templates for initializer and YAML files.    |

---

Happy configuring!

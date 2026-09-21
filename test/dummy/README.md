# Dummy App

This Rails app exists to validate the Recording Studio Terms and Conditions addon in a real host application.

## What It Covers

- Recording Studio Users Auth (email, then password) with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Recording Studio default layout with PageNav, FlatPack assets, and Tailwind source scanning (including `/usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*`)
- Dummy importmap imports `@hotwired/turbo-rails` so Admin turbo frames (hub widgets and tables) finish loading instead of staying on skeletons
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dummy-only `/docs/*` pages for gem-specific onboarding
- Acceptance gate: a workspace with live published Terms sends signed-in people to Agree until they accept
- Dummy opts in to `require_scroll_to_end` so Agree stays disabled until the live copy is scrolled to the end. Missing IntersectionObserver still leaves Agree enabled
- Dummy sets `config.app_name = "Terms Dummy"`
- Dummy `/agree_helper` also shows `recording_studio_terms_continue_notice` and POSTs `accept!` with `continue_notice`
- Hosts install with `recording_studio_terms_and_conditions:install` (mount, migrations, initializer, importmap pin)

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open `/users/sign_in`, continue with email, and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - dummy app home page and addon guidance
- `/recording_studio_terms_and_conditions` - Agree screen
- `/admin` - Recording Studio Admin Terms and Conditions hub (New parks here)
- `/recording_studio_terms_and_conditions/admin/terms` - engine write/edit form (opened from Admin). Switch to the Admin root first. New Terms is titled New Terms and Conditions.
- `/terms/:uuid/:slug` - public published Terms
- `/recordings/:id/publishable/preview` - signed-in Preview of draft or scheduled Terms
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Users Auth sign-in (email, then password)
- `/agree_helper` - embeddable Agree helpers (checkbox plus continue notice)
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify the addon experience before copying patterns into another host app. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages use Recording Studio's shared default layout. Sign-in uses Users Auth. Replace dummy docs page content so it matches the gem's actual concepts.

The home page in `app/views/home/index.html.erb` should stay a minimal demo surface for the gem's core feature. Do not turn it into a wall of documentation; the dummy docs pages exist so deeper explanations can live in focused sections.

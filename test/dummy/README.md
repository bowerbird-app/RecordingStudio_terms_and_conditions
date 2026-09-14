# Dummy App

This Rails app exists to validate the Recording Studio Terms and Conditions addon in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Recording Studio default layout with Flatpack TopNav, FlatPack assets, and Tailwind source scanning (including `/usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*`)
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dummy-only `/docs/*` pages for gem-specific onboarding
- Acceptance gate: a workspace with live published Terms sends signed-in people to Agree until they accept
- Hosts install with `recording_studio_terms_and_conditions:install` (mount, migrations, initializer)

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - dummy app home page and addon guidance
- `/recording_studio_terms_and_conditions` - Agree screen
- `/recording_studio_terms_and_conditions/admin/terms` - Admin write/edit
- `/admin` - Admin Terms section
- `/terms/:uuid/:slug` - public published Terms
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/agree_helper` - embeddable Agree helper demo (page + in-form)
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify the addon experience before copying patterns into another host app. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`. Replace dummy docs page content so it matches the gem's actual concepts.

The home page in `app/views/home/index.html.erb` should stay a minimal demo surface for the gem's core feature. Do not turn it into a wall of documentation; the dummy docs pages exist so deeper explanations can live in focused sections.

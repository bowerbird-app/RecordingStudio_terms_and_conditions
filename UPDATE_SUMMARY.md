# Recording Studio Terms and Conditions kit pin update

`recording_studio_terms_and_conditions` 0.16.0 fails closed through Accessible and pins the kit at Recording Studio 6.5.

- Gemspec: `recording_studio >= 6.3.0, < 7`, `flat_pack >= 0.1.196`, `recording_studio_accessible >= 0.24.2, < 1`, `recording_studio_admin >= 2.0.6, < 3`, `recording_studio_publishable ~> 0.6`, `recording_studio_user >= 0.12.2`
- Dummy GitHub tags: Recording Studio `v6.7.0`, Accessible `v0.32.0`, Attachable `v0.23.0`, Publishable `v0.15.0`, Admin `v2.13.0`, API `v0.23.1`, Users `v0.28.1`, Root Switchable `v0.15.0`, FlatPack `v0.1.357`, Logs `v0.7.4`, Cache `v0.6.3`, Metrics `v0.8.0`, Moveable `v4.1.1`, Icons `v0.2.1`, Internationalization `v0.2.2`, Trashable `v0.14.0`
- Root and dummy Rails locks both `8.1.4.1`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.

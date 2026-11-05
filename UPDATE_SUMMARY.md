# Recording Studio Terms and Conditions kit pin update

`recording_studio_terms_and_conditions` 0.15.0 pins the Support host kit at Recording Studio 6.3.

- Gemspec: `recording_studio >= 6.3.0, < 7`, `flat_pack >= 0.1.196`, `recording_studio_accessible ~> 0.8`, `recording_studio_admin >= 2.0.6, < 3`, `recording_studio_publishable ~> 0.6`, `recording_studio_user >= 0.12.2`
- Dummy GitHub tags: Recording Studio `v6.3.0`, Accessible `v0.24.1`, Attachable `v0.22.0`, Publishable `v0.13.0`, Admin `v2.9.1`, Users `v0.27.0`, Root Switchable `v0.11.5`, FlatPack `v0.1.341`, Logs `v0.7.3`, Cache `v0.6.2`, Metrics `v0.7.2`
- Root and dummy Rails locks both `8.1.4.1`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.

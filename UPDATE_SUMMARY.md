# Recording Studio Terms and Conditions kit pin update

`recording_studio_terms_and_conditions` starts on the Support host-kit floor.

- Gemspec: `recording_studio ~> 4.2`, `flat_pack >= 0.1.196`, `recording_studio_accessible ~> 0.8`, `recording_studio_admin ~> 2.0`, `recording_studio_publishable ~> 0.3`, `recording_studio_user >= 0.12.2`
- Dummy GitHub tags: Recording Studio `v4.2.0`, Accessible `v0.9.1`, Attachable `v0.5.1`, Publishable `v0.3.1`, Admin `v2.0.2`, Users `v0.12.2`, Root Switchable `v0.5.0`, FlatPack `v0.1.196`
- Root and dummy Rails locks both `8.1.3.1`
- Authenticated dummy layout: `RecordingStudio::UsesDefaultLayout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.

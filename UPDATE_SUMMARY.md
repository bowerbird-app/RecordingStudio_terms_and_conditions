# Recording Studio Terms and Conditions kit pin update

`recording_studio_terms_and_conditions` starts on the Support host-kit floor.

- Gemspec: `recording_studio ~> 4.2`, `flat_pack >= 0.1.196`, `recording_studio_accessible ~> 0.8`, `recording_studio_admin ~> 2.0`, `recording_studio_publishable ~> 0.4`, `recording_studio_user >= 0.12.2`
- Dummy GitHub tags: Recording Studio `v4.2.2`, Accessible `v0.11.1`, Attachable `v0.7.1`, Publishable `v0.4.2`, Admin `v2.0.4`, Users `v0.12.5`, Root Switchable `v0.5.3`, FlatPack `v0.1.196`
- Root and dummy Rails locks both `8.1.3.1`
- Authenticated dummy layout: `RecordingStudio::UsesDefaultLayout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.

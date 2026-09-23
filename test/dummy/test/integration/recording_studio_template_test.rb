# frozen_string_literal: true

require "test_helper"

class RecordingStudioTemplateTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
    assert_includes ApplicationController.ancestors, RecordingStudioTermsAndConditions::ForcesAcceptance
    assert_includes RecordingStudioUser::Auth::BaseController.ancestors,
                    RecordingStudioTermsAndConditions::UsersAuthRedirect
    assert_includes RecordingStudioUser::Auth::RegistrationsController.ancestors,
                    RecordingStudioTermsAndConditions::SignupAcceptance
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal [ "AdminRoot", "RecordingStudioUser::People", "Workspace" ].sort, RecordingStudio.root_recordable_types.sort
    assert_equal [ "Workspace", "Folder" ], RecordingStudio.allowed_parent_types_for("Page")
    assert_equal [ "Workspace" ], RecordingStudio.allowed_parent_types_for("RecordingStudioTermsAndConditions::Terms")
  end

  test "dummy app schema keeps accessible grants and excludes removed core tables" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio Workspace")
    accessible_workspace = Workspace.find_by!(name: "Client Workspace")
    private_workspace = Workspace.find_by!(name: "Private Workspace")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    admin_root = AdminRoot.find_by!(name: "Admin")
    terms = RecordingStudioTermsAndConditions.current_published_for(workspace)
    privacy = RecordingStudioTermsAndConditions.current_published_for(workspace, kind: "privacy_policy")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    accessible_root_recording = RecordingStudio::Recording.find_by!(recordable: accessible_workspace)
    private_root_recording = RecordingStudio::Recording.find_by!(recordable: private_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil accessible_root_recording.parent_recording_id
    assert_nil private_root_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal 3, Workspace.count
    assert_equal "Terms and Conditions v1.0", terms.title
    assert_equal "Privacy Policy v1.0", privacy.title
    assert_equal "terms_and_condition", terms.kind
    assert_equal "privacy_policy", privacy.kind
    terms_recording = RecordingStudio::Recording.find_by!(recordable: terms)
    privacy_recording = RecordingStudio::Recording.find_by!(recordable: privacy)
    assert_equal "terms-and-conditions", terms_recording.try(:current_publishable)&.try(:slug)
    assert_equal "privacy-policy", privacy_recording.try(:current_publishable)&.try(:slug)
    assert_includes RecordingStudioTermsAndConditions::SampleTerms::BODY, "Using the booth"
    assert_includes RecordingStudioTermsAndConditions::SampleTerms::BODY, "When something breaks"
    assert_equal "Terms and Conditions v1.0", RecordingStudioTermsAndConditions::SampleTerms::TITLE
    seeds_source = File.read(Rails.root.join("db/seeds.rb"))
    assert_includes seeds_source, "SampleTerms::BODY"
    assert_includes seeds_source, 'slug: "terms-and-conditions"'
    assert_includes seeds_source, 'slug: "privacy-policy"'
    assert_includes seeds_source, "KIND_PRIVACY"
    refute_includes seeds_source, "studio-terms"
    assert RecordingStudio::Recording.find_by!(recordable: admin_root)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudio::Recording.count } do
        load Rails.root.join("db/seeds.rb").to_s
      end
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end

  test "workspace opts into accessible and the example mixin without enabling them globally" do
    workspace_source = File.read(Rails.root.join("app/models/workspace.rb"))
    example_source = File.read(RecordingStudioTermsAndConditions::Engine.root.join("lib/recording_studio_terms_and_conditions/capabilities/example.rb"))

    assert_includes workspace_source, "include RecordingStudio::Capabilities::Example.to(label: \"dummy workspace\")"
    assert_includes example_source, "RecordingStudio::Capabilities.include_for(:example, **)"
    refute_includes example_source, "enable_capability"
    refute_includes example_source, "set_capability_options"

    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    assert RecordingStudio.capability_enabled?(:example, for: Workspace)
    assert_equal({ label: "dummy workspace" }, RecordingStudio.capability_options(:example, for: Workspace))
    refute RecordingStudio.capability_enabled?(:accessible, for: Folder)
    refute RecordingStudio.capability_enabled?(:accessible, for: Page)
    refute RecordingStudio.capability_enabled?(:example, for: Folder)
    refute RecordingStudio.capability_enabled?(:example, for: Page)
    assert_equal [ "Workspace" ], RecordingStudio.configuration.enabled_recordable_types_for(:example)
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
  end

  test "dummy terms initializer sets a concrete app_name" do
    assert_equal "Terms Dummy", RecordingStudioTermsAndConditions.configuration.app_name
    initializer = File.read(Rails.root.join("config/initializers/recording_studio_terms_and_conditions.rb"))
    assert_includes initializer, 'config.app_name = "Terms Dummy"'
  end
end

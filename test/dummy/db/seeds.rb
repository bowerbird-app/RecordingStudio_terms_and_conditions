# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
admin_root = AdminRoot.find_or_create_by!(name: "Admin")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)

  if defined?(RecordingStudioAccessible)
    unless RecordingStudioAccessible.authorized?(
      actor: user,
      recording: admin_root_recording,
      role: :edit
    )
      result = RecordingStudioAccessible.bootstrap_owner_access!(
        recording: admin_root_recording,
        actor: user
      )
      raise result.error if result.respond_to?(:failure?) && result.failure?
    end
  end

  terms_recording = RecordingStudio::Recording.find_by(
    recordable_type: RecordingStudioTermsAndConditions::Terms.name,
    root_recording: root_recording,
    trashed_at: nil
  )
  sample_title = RecordingStudioTermsAndConditions::SampleTerms::TITLE
  sample_body = RecordingStudioTermsAndConditions::SampleTerms::BODY
  if terms_recording.blank?
    terms_recording = root_recording.record(
      RecordingStudioTermsAndConditions::Terms,
      actor: user
    ) do |terms|
      terms.title = sample_title
      terms.body = sample_body
    end
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: terms_recording,
      attributes: { slug: "studio-terms", status: "published" }
    ).value!
  elsif terms_recording.recordable.title != sample_title
    terms_recording = root_recording.revise(terms_recording, actor: user) do |terms|
      terms.title = sample_title
      terms.body = sample_body
    end
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: terms_recording,
      attributes: { slug: "studio-terms", status: "published" }
    ).value!
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: AdminRoot '#{admin_root.name}' with root recording ##{admin_root_recording.id}"
puts "Seeded: published Terms and Conditions under '#{workspace.name}'"

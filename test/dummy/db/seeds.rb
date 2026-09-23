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

terms_recording_for_kind = lambda do |root_recording, kind|
  RecordingStudioTermsAndConditions::KindPresence.recordings_for(root_recording, kind: kind)
    .max_by { |recording| recording.created_at || Time.at(0) }
end

ensure_published_terms = lambda do |root_recording, user, kind:, title:, body:, slug:|
  recording = terms_recording_for_kind.call(root_recording, kind)

  if recording.blank?
    recording = root_recording.record(
      RecordingStudioTermsAndConditions::Terms,
      actor: user
    ) do |terms|
      terms.title = title
      terms.body = body
      terms.kind = kind
    end
  elsif recording.recordable.title != title || recording.recordable.body != body ||
        recording.recordable.kind.to_s != kind.to_s
    recording = RecordingStudioTermsAndConditions::TermsWrite.call(
      recording: recording,
      actor: user,
      title: title,
      body: body,
      kind: kind
    )
  end

  current_slug = recording.try(:current_publishable)&.try(:slug)
  if !recording.currently_published? || current_slug != slug
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: "published" }
    ).value!
    recording = recording.reload
  end

  recording
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
    unless RecordingStudioAccessible.authorized?(actor: user, recording: root_recording, role: :edit)
      result = RecordingStudioAccessible.bootstrap_owner_access!(
        recording: root_recording,
        actor: user
      )
      raise result.error if result.respond_to?(:failure?) && result.failure?
    end
  end

  ensure_published_terms.call(
    root_recording,
    user,
    kind: RecordingStudioTermsAndConditions::Terms::KIND_TERMS,
    title: RecordingStudioTermsAndConditions::SampleTerms::TITLE,
    body: RecordingStudioTermsAndConditions::SampleTerms::BODY,
    slug: "terms-and-conditions"
  )

  ensure_published_terms.call(
    root_recording,
    user,
    kind: RecordingStudioTermsAndConditions::Terms::KIND_PRIVACY,
    title: "Privacy Policy v1.0",
    body: "<p>We keep the version you agreed to and a receipt of when you agreed. That is the privacy trail for this workspace.</p>",
    slug: "privacy-policy"
  )
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
puts "Seeded: published Privacy Policy under '#{workspace.name}'"

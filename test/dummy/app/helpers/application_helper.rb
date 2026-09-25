module ApplicationHelper
  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )
  end

  def dummy_admin_hub_switch_href
    recording = dummy_admin_root_recording
    return "/admin" unless recording

    query = {
      scope: "all_workspaces",
      root_switch: { root_recording_id: recording.id, return_to: "/admin" }
    }.to_query
    "/recording_studio_root_switchable/v1/root_switch?#{query}"
  end

  def dummy_published_page_url(kind)
    RecordingStudioTermsAndConditions::Admin.live_page_url(kind)
  end

  def recording_studio_terms_demo_documents
    root = recording_studio_terms_agree_root
    RecordingStudioTermsAndConditions.current_published_by_kind(root).values.compact
  end

  def dummy_admin_root_recording
    admin_root = AdminRoot.find_by(name: "Admin")
    RecordingStudio.root_recording_for(admin_root) if admin_root
  end
end

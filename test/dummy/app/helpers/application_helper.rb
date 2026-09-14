module ApplicationHelper
  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )
  end

  def dummy_top_nav
    render "layouts/flat_pack/top_nav"
  end

  def dummy_admin_hub_switch_href
    admin_root = AdminRoot.find_by(name: "Admin")
    return "/admin" unless admin_root

    recording = RecordingStudio.root_recording_for(admin_root)
    query = {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: recording.id,
        return_to: "/admin"
      }
    }.to_query

    "/recording_studio_root_switchable/v1/root_switch?#{query}"
  end
end

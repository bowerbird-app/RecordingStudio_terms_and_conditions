# frozen_string_literal: true

require "recording_studio_admin"

module RecordingStudioTermsAndConditions
  module Admin
    class TermsSection < RecordingStudioAdmin::Section
      key "terms"
      icon :document_text
      title "Terms and Conditions"
      subtitle "Write them, publish them, see who agreed"
      blast_radius :site

      link :write,
           text: "New",
           url: ->(_context) { RecordingStudioTermsAndConditions.admin_write_path },
           style: :primary
      link :versions,
           text: "All versions",
           url: ->(context) { context.admin_screen_path("recording_studio_terms") },
           style: :secondary
      link :agrees,
           text: "Agree stats",
           url: ->(context) { context.admin_screen_path("recording_studio_terms_acceptances") },
           style: :secondary
      widget "widgets.terms.live", view_variant: :card
      widget "widgets.terms.agrees", view_variant: :card
    end

    class TermsScreen < RecordingStudioAdmin::Screen
      key "recording_studio_terms"
      icon :document_text
      title "All versions"
      subtitle "Drafts and live copies"
      blast_radius :site
      query do |_context|
        RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
                                  .includes(:recordable)
                                  .order(updated_at: :desc)
      end

      table do
        title "All versions"
        paginate per_page: 25
        column :title,
               title: "Title",
               sortable: false,
               value: ->(recording, _context) { recording.recordable&.title }
        column :status,
               title: "Status",
               sortable: false,
               value: lambda { |recording, _context|
                 recording.respond_to?(:currently_published?) && recording.currently_published? ? "Live" : "Draft"
               }
        column :published,
               title: "Published",
               sortable: false,
               value: lambda { |recording, _context|
                 recording.try(:current_publishable)&.try(:publish_at)
               }
        column :agrees,
               title: "Agrees",
               sortable: false,
               value: ->(recording, _context) { Acceptance.where(terms_recording_id: recording.id).count }
        admin_action "terms.show", as: :open
        admin_action "terms.edit"
        admin_action "terms.users"
      end
      widget "widgets.terms.live", view_variant: :card
      widget "widgets.terms.agrees", view_variant: :card
    end

    class AcceptancesScreen < RecordingStudioAdmin::Screen
      key "recording_studio_terms_acceptances"
      icon :check_circle
      title "Agree stats"
      subtitle "Receipts for the live clickwrap"
      blast_radius :site
      query { |_context| Acceptance.order(accepted_at: :desc) }

      table do
        title "Users"
        paginate per_page: 25
        column :actor,
               title: "Person",
               sortable: false,
               value: ->(row, _context) { row.actor.try(:email) || "Someone" }
        column :accepted_at, title: "Agreed"
        column :terms,
               title: "Terms",
               sortable: false,
               value: lambda { |row, _context|
                 Terms.find_by(id: row.terms_id)&.title || "A past version"
               }
      end
      widget "widgets.terms.agrees", view_variant: :card
    end

    LiveTermsWidget = RecordingStudioAdmin::Widget.new("widgets.terms.live", blast_radius: :site) do
      type :number
      title "Live"
      info "Published terms people can agree to right now."
      value do |_context|
        RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil).to_a.count do |recording|
          recording.respond_to?(:currently_published?) && recording.currently_published?
        end
      end
      link_to { |context| context.admin_screen_path("recording_studio_terms") }
      hide_change
      hide_period
    end

    class TermsResource < RecordingStudioAdmin::Resource
      key "terms"
      section "terms"
      icon :document_text
      title "Terms"
      subtitle "Open a version, edit a draft, or check who agreed"
      blast_radius :site

      action :show,
             text: "Open",
             icon: "eye",
             url: lambda { |recording, _context|
               RecordingStudioTermsAndConditions.admin_term_path(recording) if recording
             },
             visible_if: ->(recording, _context) { recording.present? }

      action :edit,
             text: "Edit",
             icon: "pencil-square",
             required_role: :edit,
             url: lambda { |recording, _context|
               RecordingStudioTermsAndConditions.edit_admin_term_path(recording) if recording
             },
             visible_if: ->(recording, _context) { recording.present? }

      action :users,
             text: "Users",
             icon: "user-group",
             url: lambda { |recording, _context|
               RecordingStudioTermsAndConditions.admin_term_users_path(recording) if recording
             },
             visible_if: ->(recording, _context) { recording.present? }

      action :index,
             text: "All versions",
             url: ->(_recording, _context) { RecordingStudioTermsAndConditions.admin_terms_path }

      action :new,
             text: "New",
             icon: "plus",
             required_role: :edit,
             url: ->(_recording, _context) { RecordingStudioTermsAndConditions.admin_write_path }
    end

    AgreesWidget = RecordingStudioAdmin::Widget.new("widgets.terms.agrees", blast_radius: :site) do
      type :number
      title "Agrees"
      info "Clickwrap receipts, all versions."
      value { |_context| Acceptance.count }
      link_to { |context| context.admin_screen_path("recording_studio_terms_acceptances") }
      hide_change
      hide_period
    end

    unless const_defined?(:DEFINITION_CONSTANTS, false)
      DEFINITION_CONSTANTS = %i[
        TermsSection
        TermsScreen
        AcceptancesScreen
        TermsResource
        LiveTermsWidget
        AgreesWidget
      ].freeze
    end

    class << self
      def reset_definition_constants!
        DEFINITION_CONSTANTS.each do |name|
          remove_const(name) if const_defined?(name, false)
        end
      end

      def register!
        RecordingStudioAdmin.register_section(TermsSection)
        RecordingStudioAdmin.register_screen(TermsScreen)
        RecordingStudioAdmin.register_screen(AcceptancesScreen)
        RecordingStudioAdmin.register_resource(TermsResource)
        register_widget!(LiveTermsWidget)
        register_widget!(AgreesWidget)
      end

      def register_widget!(widget)
        RecordingStudioAdmin.register_widget(widget)
      rescue RecordingStudioAdmin::RegistryConflict
        RecordingStudioAdmin.registry.widgets[widget.key.to_s] = widget
      end
    end
  end

  def self.admin_terms_path
    engine_admin_path(:admin_terms_path)
  end

  def self.admin_write_path
    engine_admin_path(:new_admin_term_path)
  end

  def self.admin_term_path(recording)
    engine_admin_path(:admin_term_path, recording)
  end

  def self.edit_admin_term_path(recording)
    engine_admin_path(:edit_admin_term_path, recording)
  end

  def self.admin_term_users_path(recording)
    engine_admin_path(:admin_term_users_path, recording)
  end

  def self.engine_admin_path(helper, *)
    Engine.routes.url_helpers.public_send(
      helper,
      *,
      script_name: configuration.mount_path
    )
  end
  private_class_method :engine_admin_path

  def self.admin_hub_path
    if defined?(RecordingStudioAdmin)
      RecordingStudioAdmin.configuration.default_mount_path.presence || "/admin"
    else
      admin_terms_path
    end
  end
end

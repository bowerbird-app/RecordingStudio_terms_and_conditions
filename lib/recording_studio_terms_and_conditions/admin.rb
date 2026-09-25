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

      link :terms_page,
           text: "Terms and Condition page",
           url: ->(_context) { Admin.live_page_url(Terms::KIND_TERMS) },
           style: :ghost,
           visible_if: ->(_context) { Admin.live_page_url(Terms::KIND_TERMS).present? }
      link :privacy_page,
           text: "Privacy Policy page",
           url: ->(_context) { Admin.live_page_url(Terms::KIND_PRIVACY) },
           style: :ghost,
           visible_if: ->(_context) { Admin.live_page_url(Terms::KIND_PRIVACY).present? }
      link :edit_terms,
           text: "Edit Terms",
           url: ->(_context) { Admin.live_edit_url(Terms::KIND_TERMS) },
           style: :secondary,
           visible_if: ->(_context) { Admin.live_edit_url(Terms::KIND_TERMS).present? }
      link :edit_privacy,
           text: "Edit Privacy Policy",
           url: ->(_context) { Admin.live_edit_url(Terms::KIND_PRIVACY) },
           style: :secondary,
           visible_if: ->(_context) { Admin.live_edit_url(Terms::KIND_PRIVACY).present? }
      # Keeps the version and agree-stats screens enabled. The admin hub hides this label.
      link :versions,
           text: "Admin Sections",
           url: ->(context) { context.admin_screen_path("recording_studio_terms") }
      link :agrees,
           text: "Admin Sections",
           url: ->(context) { context.admin_screen_path("recording_studio_terms_acceptances") }
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

      # rubocop:disable Metrics/BlockLength
      table do
        title "All versions"
        paginate per_page: 25
        column :title,
               title: "Title",
               sortable: false,
               value: ->(recording, _context) { recording.recordable&.title }
        column :kind,
               title: "Type",
               sortable: false,
               value: ->(recording, _context) { recording.recordable&.kind_label }
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
      # rubocop:enable Metrics/BlockLength
      widget "widgets.terms.live", view_variant: :card
      widget "widgets.terms.agrees", view_variant: :card
    end

    class AcceptancesScreen < RecordingStudioAdmin::Screen
      key "recording_studio_terms_acceptances"
      icon :check_circle
      title "Who agreed"
      subtitle "Newest agreement first"
      blast_radius :site
      query { |_context| AgreedPeople.relation }

      table do
        title "Users"
        paginate per_page: 25
        column :name,
               title: "Name",
               sortable: false,
               value: ->(row, _context) { Admin.actor_name(row.actor) }
        column :terms_accepted_at,
               title: "Agreed terms",
               sortable: false,
               value: ->(row, _context) { row.read_attribute("terms_accepted_at") }
        column :privacy_accepted_at,
               title: "Agreed privacy",
               sortable: false,
               value: ->(row, _context) { row.read_attribute("privacy_accepted_at") }
        column :actions,
               title: "Actions",
               sortable: false,
               value: lambda { |row, context|
                 context.view_context.render(
                   FlatPack::Button::Component.new(
                     text: "View",
                     style: :secondary,
                     size: :sm,
                     href: RecordingStudioTermsAndConditions.admin_person_path(row.actor_type, row.actor_id)
                   )
                 )
               }
      end
      widget "widgets.terms.agrees", view_variant: :card
    end

    module AgreedPeople
      module_function

      def relation
        terms = Terms.arel_table
        Acceptance.joins("INNER JOIN #{terms.name} ON #{terms.name}.id = #{Acceptance.table_name}.terms_id")
                  .select(
                    "#{Acceptance.table_name}.actor_type",
                    "#{Acceptance.table_name}.actor_id",
                    "MAX(#{Acceptance.table_name}.accepted_at) AS latest_accepted_at",
                    kind_date_sql(terms, Terms::KIND_TERMS, "terms_accepted_at"),
                    kind_date_sql(terms, Terms::KIND_PRIVACY, "privacy_accepted_at")
                  )
                  .group("#{Acceptance.table_name}.actor_type", "#{Acceptance.table_name}.actor_id")
                  .order(Arel.sql("MAX(#{Acceptance.table_name}.accepted_at) DESC"))
      end

      def kind_date_sql(terms, kind, alias_name)
        "MAX(#{Acceptance.table_name}.accepted_at) FILTER " \
          "(WHERE #{terms.name}.kind = #{Acceptance.connection.quote(kind)}) AS #{alias_name}"
      end
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
      def live_recording(kind)
        return unless defined?(RecordingStudio::Recording)

        RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
                                  .includes(:recordable)
                                  .select { |recording| live_kind?(recording, kind) }
                                  .max_by { |recording| recording.updated_at || Time.at(0) }
      end

      def live_page_url(kind)
        live_recording(kind)&.recordable&.try(:published_url)
      end

      def live_edit_url(kind)
        recording = live_recording(kind)
        return if recording.blank?

        RecordingStudioTermsAndConditions.edit_admin_term_path(recording)
      end

      def actor_name(actor)
        return "Someone" if actor.blank?

        actor.try(:name).presence || actor.try(:email).presence || "Someone"
      end

      def live_kind?(recording, kind)
        recording.recordable&.kind.to_s == kind.to_s &&
          recording.respond_to?(:currently_published?) &&
          recording.currently_published?
      end

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

  def self.admin_person_path(actor_type, actor_id)
    engine_admin_path(:admin_person_path, actor_type, actor_id)
  end

  def self.agreed_people_screen_path
    "#{admin_hub_path}/screens/recording_studio_terms_acceptances"
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

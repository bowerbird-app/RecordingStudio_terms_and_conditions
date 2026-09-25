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
           style: :secondary,
           visible_if: ->(_context) { Admin.live_page_url(Terms::KIND_TERMS).present? }
      link :privacy_page,
           text: "Privacy Policy page",
           url: ->(_context) { Admin.live_page_url(Terms::KIND_PRIVACY) },
           style: :secondary,
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
      widget "widgets.terms.terms_agreed", view_variant: :card
      widget "widgets.terms.privacy_agreed", view_variant: :card
    end

    class TermsScreen < RecordingStudioAdmin::Screen
      key "recording_studio_terms"
      icon :document_text
      title "All versions"
      subtitle "Drafts and live copies"
      blast_radius :site
      query { |_context| AdminVersions.relation }

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
    end

    class AcceptancesScreen < RecordingStudioAdmin::Screen
      key "recording_studio_terms_acceptances"
      icon :check_circle
      title "Who agreed"
      subtitle "Newest agreement first"
      blast_radius :site
      query { |_context| AgreedPeople.relation }
      filter_presentation :inline
      filter :name_or_email, apply: lambda { |relation, value, _context|
        AgreedPeople.matching_name_or_email(relation, value)
      }

      table do
        title "Users"
        paginate per_page: 25
        column :name, title: "Name", sortable: false, value: ->(row, _context) { Admin.actor_name(row.actor) }
        column :terms_accepted_at, title: "Agreed terms", sortable: false,
                                   value: ->(row, _context) { row.read_attribute("terms_accepted_at") }
        column :privacy_accepted_at, title: "Agreed privacy", sortable: false,
                                     value: ->(row, _context) { row.read_attribute("privacy_accepted_at") }
        column :actions, title: "Actions", sortable: false, value: lambda { |row, context|
          href = RecordingStudioTermsAndConditions.admin_person_path(row.actor_type, row.actor_id)
          context.view_context.render(
            FlatPack::Button::Component.new(text: "View", style: :secondary, size: :sm, href: href)
          )
        }
      end
    end

    module AgreedPeople
      module_function

      def relation
        terms = Terms.arel_table
        Acceptance.joins(terms_join(terms)).select(select_sql(terms)).group(group_sql).order(newest_first)
      end

      def select_sql(terms)
        [
          "#{Acceptance.table_name}.actor_type",
          "#{Acceptance.table_name}.actor_id",
          "MAX(#{Acceptance.table_name}.accepted_at) AS latest_accepted_at",
          kind_date_sql(terms, Terms::KIND_TERMS, "terms_accepted_at"),
          kind_date_sql(terms, Terms::KIND_PRIVACY, "privacy_accepted_at")
        ]
      end

      def terms_join(terms)
        "INNER JOIN #{terms.name} ON #{terms.name}.id = #{Acceptance.table_name}.terms_id"
      end

      def group_sql
        "#{Acceptance.table_name}.actor_type, #{Acceptance.table_name}.actor_id"
      end

      def newest_first
        Arel.sql("MAX(#{Acceptance.table_name}.accepted_at) DESC")
      end

      def matching_name_or_email(relation, raw)
        term = "%#{Acceptance.sanitize_sql_like(raw.to_s.strip)}%"
        relation.joins(people_join).where(people_match_sql, term: term)
      end

      def people_join
        acceptances = Acceptance.table_name
        "LEFT JOIN users ON users.id = #{acceptances}.actor_id " \
          "AND #{acceptances}.actor_type = 'User' " \
          "LEFT JOIN recording_studio_user_profiles profiles ON profiles.user_id = users.id"
      end

      def people_match_sql
        "users.email ILIKE :term OR profiles.first_name ILIKE :term OR " \
          "profiles.last_name ILIKE :term OR " \
          "(profiles.first_name || ' ' || profiles.last_name) ILIKE :term"
      end

      def kind_date_sql(terms, kind, alias_name)
        "MAX(#{Acceptance.table_name}.accepted_at) FILTER " \
          "(WHERE #{terms.name}.kind = #{Acceptance.connection.quote(kind)}) AS #{alias_name}"
      end
    end

    TermsAgreedWidget = RecordingStudioAdmin::Widget.new("widgets.terms.terms_agreed", blast_radius: :site) do
      type :number
      title "Terms and conditions"
      info "People who agreed to Terms and Conditions."
      value { |_context| AdminVersions.agreed_label(Terms::KIND_TERMS) }
      hide_change
      hide_period
    end

    PrivacyAgreedWidget = RecordingStudioAdmin::Widget.new("widgets.terms.privacy_agreed", blast_radius: :site) do
      type :number
      title "Privacy Policy"
      info "People who agreed to the Privacy Policy."
      value { |_context| AdminVersions.agreed_label(Terms::KIND_PRIVACY) }
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

    unless const_defined?(:DEFINITION_CONSTANTS, false)
      DEFINITION_CONSTANTS = %i[
        TermsSection
        TermsScreen
        AcceptancesScreen
        TermsResource
        TermsAgreedWidget
        PrivacyAgreedWidget
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
        register_widget!(TermsAgreedWidget)
        register_widget!(PrivacyAgreedWidget)
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
    return admin_terms_path unless defined?(RecordingStudioAdmin)

    RecordingStudioAdmin.configuration.default_mount_path.presence || "/admin"
  end

  module AdminVersions
    module_function

    def relation
      RecordingStudio::Recording.where(recordable_type: Terms.name, trashed_at: nil)
                                .includes(:recordable)
                                .order(Arel.sql(order_sql))
    end

    def agreed_label(kind)
      "#{people_count(kind)} user agreed"
    end

    def people_count(kind)
      terms = Terms.arel_table
      Acceptance.joins(Admin::AgreedPeople.terms_join(terms))
                .where(terms[:kind].eq(kind))
                .distinct
                .count(Arel.sql("CONCAT(#{Acceptance.table_name}.actor_type, #{Acceptance.table_name}.actor_id)"))
    end

    def order_sql
      recordings = RecordingStudio::Recording.table_name
      "CASE WHEN EXISTS (#{live_sql(recordings)}) THEN 0 ELSE 1 END, #{recordings}.updated_at DESC"
    end

    def live_sql(recordings)
      publishables = "recording_studio_publishable_publishables"
      "SELECT 1 FROM #{recordings} AS publishable_recordings " \
        "INNER JOIN #{publishables} AS publishables ON publishables.id = publishable_recordings.recordable_id " \
        "WHERE publishable_recordings.parent_recording_id = #{recordings}.id " \
        "AND publishable_recordings.recordable_type = 'RecordingStudioPublishable::Publishable' " \
        "AND publishable_recordings.trashed_at IS NULL AND publishables.status = 'published' " \
        "AND (publishables.publish_at IS NULL OR publishables.publish_at <= CURRENT_TIMESTAMP) " \
        "AND (publishables.unpublish_at IS NULL OR publishables.unpublish_at > CURRENT_TIMESTAMP)"
    end
  end
end

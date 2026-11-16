# frozen_string_literal: true

require "test_helper"

class GateTest < Minitest::Test
  FakeController = Struct.new(:controller_path, :devise_flag) do
    def devise_controller?
      devise_flag
    end
  end

  def setup
    RecordingStudioTermsAndConditions::Gate.register!
  end

  def test_exempts_clickwrap_auth_and_operator_screens
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_terms_and_conditions/acceptances", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_user/auth/registrations", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("agree_helpers", false))
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_terms_and_conditions/admin/terms", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_terms_and_conditions/published_terms", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(
      FakeController.new("recording_studio_publishable/publishables", false)
    )
    assert RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("devise/sessions", false))
    assert RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("home", true))
    refute RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("home", false))
    refute RecordingStudioTermsAndConditions::Gate.exempt?(FakeController.new("docs", false))
  end

  def test_after_auth_path_is_nil_when_nothing_is_pending
    controller = Object.new

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [] }) do
      assert_nil RecordingStudioTermsAndConditions::Gate.after_auth_path(controller, :actor)
      assert_nil RecordingStudioTermsAndConditions::Gate.after_auth_path(controller, nil)
    end
  end

  def test_acceptance_path_prefers_the_mounted_engine_helper
    helper = Object.new
    def helper.acceptance_path
      "/mounted-agree"
    end
    controller = Object.new
    controller.define_singleton_method(:recording_studio_terms_and_conditions) { helper }

    assert_equal "/mounted-agree", RecordingStudioTermsAndConditions::Gate.acceptance_path(controller)
  end

  def test_acceptance_path_falls_back_to_the_local_helper
    controller = Object.new
    def controller.acceptance_path
      "/local-agree"
    end

    assert_equal "/local-agree", RecordingStudioTermsAndConditions::Gate.acceptance_path(controller)
  end

  def test_pending_for_ignores_the_current_workspace
    controller = Object.new
    def controller.acceptance_path
      "/agree"
    end

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(actor) { actor == :actor ? [:terms] : [] }) do
      assert_equal [:terms],
                   RecordingStudioTermsAndConditions::Gate.pending_for(:actor, root: :workspace, controller: controller)
      decision = RecordingStudio.check_gate(
        RecordingStudioTermsAndConditions::Gate::GATE_NAME,
        actor: :actor,
        root: :other_workspace,
        controller: controller
      )
      assert_predicate decision, :denied?
      assert_equal "/agree", decision.redirect_to
      assert_equal "pending", decision.reason
    end
  end

  def test_acceptance_gate_is_registered_under_the_gem_name
    gate = RecordingStudioTermsAndConditions::Gate

    assert_equal "recording_studio_terms_and_conditions.acceptance", gate::GATE_NAME
    assert RecordingStudio.gate_registered?(gate::GATE_NAME)
    assert_equal([gate::CHECK_NAME], RecordingStudio.gate_checks(gate::GATE_NAME).map { |check| check[:name] })
  end

  def test_register_is_idempotent
    gate = RecordingStudioTermsAndConditions::Gate
    previous = Rails.logger
    io = StringIO.new
    Rails.logger = Logger.new(io)

    gate.register!
    gate.register!

    refute_includes io.string, "Replacing check"
    assert_equal([gate::CHECK_NAME], RecordingStudio.gate_checks(gate::GATE_NAME).map { |check| check[:name] })
  ensure
    Rails.logger = previous
  end

  def test_check_denies_when_the_shared_library_still_has_pending_terms
    seen = nil
    RecordingStudioTermsAndConditions.stub(:pending_published_list, lambda { |actor|
      seen = actor
      [:terms]
    }) do
      decision = RecordingStudio.check_gate(
        RecordingStudioTermsAndConditions::Gate::GATE_NAME,
        actor: :ada,
        root: :workspace,
        recording: :ignored
      )

      assert_equal :ada, seen
      assert_predicate decision, :denied?
      assert_nil decision.redirect_to
      assert_equal "pending", decision.reason
      assert_equal RecordingStudioTermsAndConditions::Gate::GATE_NAME, decision.gate
      assert_equal RecordingStudioTermsAndConditions::Gate::CHECK_NAME, decision.check
    end
  end

  def test_pending_for_does_not_read_the_passed_root
    controller = Object.new
    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(actor) { actor == :actor ? [] : [:terms] }) do
      assert_empty RecordingStudioTermsAndConditions::Gate.pending_for(
        :actor, root: :explicit, controller: controller
      )
      decision = RecordingStudio.check_gate(
        RecordingStudioTermsAndConditions::Gate::GATE_NAME,
        actor: :actor,
        root: :explicit,
        controller: controller
      )
      assert_predicate decision, :allowed?
    end
  end

  def test_check_allows_when_nothing_is_pending
    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [] }) do
      accepted = RecordingStudio.check_gate(
        RecordingStudioTermsAndConditions::Gate::GATE_NAME,
        actor: :ada,
        root: :workspace
      )
      unsigned = RecordingStudio.check_gate(
        RecordingStudioTermsAndConditions::Gate::GATE_NAME,
        actor: nil,
        root: :workspace
      )

      assert_predicate accepted, :allowed?
      assert_predicate unsigned, :allowed?
    end
  end

  def test_a_raising_check_still_sends_a_signed_in_actor_to_agree
    gate = RecordingStudioTermsAndConditions::Gate
    RecordingStudio.unregister_gate(gate::GATE_NAME, gate::CHECK_NAME)
    RecordingStudio.register_gate(gate::GATE_NAME, gate::CHECK_NAME) { |**| raise "terms lookup failed" }
    controller = acceptance_controller("home")

    controller.send(:force_terms_acceptance)

    assert_equal "/agree", controller.redirected_to
    assert_equal "/docs/install", controller.stored_path
  ensure
    RecordingStudio.unregister_gate(gate::GATE_NAME, gate::CHECK_NAME)
    gate.register!
  end

  def test_force_terms_acceptance_redirects_to_the_gate_decision
    controller = acceptance_controller("home")
    RecordingStudioTermsAndConditions::Gate.stub(:pending_for, [:terms]) do
      controller.send(:force_terms_acceptance)
    end

    assert_equal "/agree", controller.redirected_to
    assert_equal "/docs/install", controller.stored_path
  end

  def test_force_terms_acceptance_skips_exempt_controllers
    gate = RecordingStudioTermsAndConditions::Gate
    RecordingStudio.unregister_gate(gate::GATE_NAME, gate::CHECK_NAME)
    RecordingStudio.register_gate(gate::GATE_NAME, gate::CHECK_NAME) do |**|
      RecordingStudio::GateDecision.deny(redirect_to: "/nope", reason: "pending")
    end
    controller = acceptance_controller("recording_studio_terms_and_conditions/acceptances")

    controller.send(:force_terms_acceptance)

    assert_nil controller.redirected_to
  ensure
    RecordingStudio.unregister_gate(gate::GATE_NAME, gate::CHECK_NAME)
    gate.register!
  end

  def test_after_auth_path_uses_a_denied_gate_decision
    controller = Object.new
    def controller.acceptance_path
      "/agree"
    end

    RecordingStudioTermsAndConditions::Gate.stub(:pending_for, [:terms]) do
      assert_equal "/agree", RecordingStudioTermsAndConditions::Gate.after_auth_path(controller, :actor)
    end
  end

  def test_users_auth_redirect_falls_through_when_acceptance_is_not_required
    controller = Class.new do
      prepend RecordingStudioTermsAndConditions::UsersAuthRedirect

      def after_sign_in_path_for(_resource)
        "/after-in"
      end

      def after_sign_up_path_for(_resource)
        "/after-up"
      end

      def current_root_recordable
        nil
      end
    end.new

    RecordingStudioTermsAndConditions.stub(:pending_published_list, ->(*) { [] }) do
      assert_equal "/after-in", controller.after_sign_in_path_for(:user)
      assert_equal "/after-up", controller.after_sign_up_path_for(:user)
    end
  end

  def test_gate_files_reuse_domain_helpers
    gate = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/gate.rb", __dir__))
    forces = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/forces_acceptance.rb", __dir__))
    users = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/users_auth_redirect.rb", __dir__))

    assert_includes gate, "pending_published_list"
    assert_includes gate, "def pending_for"
    refute_includes gate, "root_for_acceptance"
    refute_includes gate, "first_root_with_live_terms"
    refute_includes gate, "live_terms_on?"
    assert_includes gate, "recording_studio_terms_and_conditions.acceptance"
    assert_includes gate, "RecordingStudio.register_gate"
    assert_includes gate, "RecordingStudio.check_gate"
    refute_includes gate, "find_each"
    refute_includes gate, "root = root_for(controller)"
    assert_includes forces, "force_terms_acceptance"
    assert_includes forces, "RecordingStudio.check_gate"
    assert_includes forces, "Gate.exempt?"
    assert_includes forces, "decision.redirect_to"
    assert_includes forces, "store_location_for"
    refute_includes forces, "Gate.pending_for"
    refute_includes forces, "terms_gate_notice"
    refute_includes forces, "We've updated our Terms and Conditions"
    refute_includes forces, "notice:"
    assert_includes users, "after_sign_up_path_for"
    assert_includes users, "Gate.after_auth_path"
    refute_includes forces, "Acceptance.create"
    refute_includes gate, "accepted?"
    acceptance = File.read(
      File.expand_path("../app/controllers/recording_studio_terms_and_conditions/acceptances_controller.rb", __dir__)
    )
    refute_includes acceptance, "Gate.root_for_acceptance"
    assert_includes acceptance, "accepted_any?"
    signup = File.read(File.expand_path("../lib/recording_studio_terms_and_conditions/signup_acceptance.rb", __dir__))
    refute_includes signup, "Gate.root_for_acceptance"
    assert_includes signup, "pending_published_list"
  end

  private

  def acceptance_controller(path)
    Class.new do
      def self.before_action(*) end

      include RecordingStudioTermsAndConditions::ForcesAcceptance

      attr_reader :redirected_to, :stored_path

      def initialize(path)
        @path = path
      end

      def current_user
        :ada
      end

      def controller_path
        @path
      end

      def devise_controller?
        false
      end

      def request
        Struct.new(:get?, :fullpath).new(true, "/docs/install")
      end

      def store_location_for(_scope, location)
        @stored_path = location
      end

      def acceptance_path
        "/agree"
      end

      def redirect_to(location)
        @redirected_to = location
      end
    end.new(path)
  end
end

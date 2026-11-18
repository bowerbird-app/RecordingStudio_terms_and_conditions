# frozen_string_literal: true

require "test_helper"

class ActorSearchTest < Minitest::Test
  def setup
    @configuration = RecordingStudioTermsAndConditions.configuration
    @previous = @configuration.actor_name_search
  end

  def teardown
    @configuration.actor_name_search = @previous
  end

  def test_blank_term_skips_the_host_callable
    called = false
    @configuration.actor_name_search = lambda { |_relation, _term|
      called = true
      :narrowed
    }

    assert_equal :relation, RecordingStudioTermsAndConditions::ActorSearch.apply(:relation, "  ")
    refute called
  end

  def test_without_a_callable_the_relation_stays_put
    @configuration.actor_name_search = nil

    assert_equal :relation, RecordingStudioTermsAndConditions::ActorSearch.apply(:relation, "Ada")
  end

  def test_host_callable_receives_the_relation_and_stripped_term
    seen = nil
    @configuration.actor_name_search = lambda { |relation, term|
      seen = [relation, term]
      :narrowed
    }

    assert_equal :narrowed, RecordingStudioTermsAndConditions::ActorSearch.apply(:relation, " Ada ")
    assert_equal [:relation, "Ada"], seen
  end

  def test_actor_name_search_rejects_a_non_callable
    assert_raises(ArgumentError) { @configuration.actor_name_search = "email" }
  end
end

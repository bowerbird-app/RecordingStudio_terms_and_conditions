# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  Copy = RecordingStudioTermsAndConditions::Copy

  def setup
    I18n.load_path |= [File.join(engine_locales_dir, "en.yml")]
    I18n.backend.load_translations
    I18n.available_locales = Array(I18n.available_locales) | %i[en fr]
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "Terms and Conditions", Copy.t("accept.first.terms")
      assert_equal "Privacy Policy", Copy.t("accept.first.privacy")
      assert_equal "Terms and Conditions and Privacy Policy", Copy.t("accept.first.both")
      assert_equal "We have updated our terms and conditions.", Copy.t("accept.updated.terms")
      assert_equal "We have updated our privacy policy.", Copy.t("accept.updated.privacy")
      assert_equal "We have updated our terms and conditions and privacy policy.", Copy.t("accept.updated.both")
      assert_equal "Continue", Copy.t("accept.continue")
      assert_equal "Nothing to agree to yet", Copy.t("accept.empty_title")
      assert_equal "I agree to these terms", Copy.t("agree.label")
      assert_equal "I agree to these terms and privacy policy", Copy.t("agree.label_with_privacy")
      assert_equal "Agree", Copy.t("agree.button")
      assert_equal "Terms & Conditions", Copy.t("continue_notice.terms")
      assert_equal "privacy policy", Copy.t("continue_notice.privacy")
      assert_equal "There are no live terms to agree to.", Copy.t("flashes.no_live_terms")
      assert_equal "Those terms aren't live. Refresh and agree to the current ones.", Copy.t("flashes.not_live")
      assert_equal "Only live terms can be accepted.", Copy.t("errors.not_live")
      assert_equal "Tick the box if you agree.", Copy.t("errors.must_agree")
    end
  end

  def test_component_text_overrides_win_including_nil
    assert_equal "Agree", Copy.value(Copy::UNSET, "agree.button")
    assert_equal "Accept", Copy.value("Accept", "agree.button")
    assert_nil Copy.value(nil, "agree.button")
  end

  def test_defaulted_follows_locale_until_the_host_changes_the_string
    I18n.with_locale(:en) do
      assert_equal "Agree", Copy.defaulted("Agree", "Agree", "agree.button")
      assert_equal "Accept", Copy.defaulted("Accept", "Agree", "agree.button")
      assert_equal "Agree", Copy.defaulted(nil, "Agree", "agree.button")
    end
  end

  def test_html_continue_notice_keys_escape_app_name_and_keep_safe_documents
    html = Copy.interpolate_html(
      "continue_notice.with_app_html",
      app_name: "<script>x</script>",
      documents: "<button>Terms &amp; Conditions</button>".html_safe
    )

    assert_predicate html, :html_safe?
    assert_includes html, "<button>Terms &amp; Conditions</button>"
    refute_includes html, "<script>"
    assert_includes html, "&lt;script&gt;x&lt;/script&gt;"
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_terms_and_conditions.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  def test_defaulted_button_label_follows_the_locale
    I18n.available_locales = Array(I18n.available_locales) | %i[en fr]
    I18n.backend.store_translations(:fr, french_button)

    I18n.with_locale(:fr) do
      assert_equal "J’accepte", Copy.defaulted("Agree", "Agree", "agree.button")
      assert_equal "Accept", Copy.defaulted("Accept", "Agree", "agree.button")
    end
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio").fetch("terms_and_conditions")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end

  def french_button
    { recording_studio: { terms_and_conditions: { agree: { button: "J’accepte" } } } }
  end
end

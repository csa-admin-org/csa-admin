# frozen_string_literal: true

require "test_helper"

class Formtastic::HtmlHintLocalizerTest < ActiveSupport::TestCase
  test "resolves hint from _html key automatically" do
    I18n.backend.store_translations(:en, {
      formtastic: {
        hints: {
          fake_model: {
            fake_attr_html: "Hint with <a href='/test'>link</a>"
          }
        }
      }
    })

    localizer = build_localizer_for("fake_model")
    result = localizer.localize(:fake_attr, nil, :hint)

    assert_equal "Hint with <a href='/test'>link</a>", result
    assert_predicate result, :html_safe?
  ensure
    clear_stored_translations
  end

  test "prefers plain key over _html key for hints" do
    I18n.backend.store_translations(:en, {
      formtastic: {
        hints: {
          fake_model: {
            fake_attr: "Plain hint",
            fake_attr_html: "HTML hint"
          }
        }
      }
    })

    localizer = build_localizer_for("fake_model")
    result = localizer.localize(:fake_attr, nil, :hint)

    assert_equal "Plain hint", result
  ensure
    clear_stored_translations
  end

  test "does not use _html key for labels" do
    I18n.backend.store_translations(:en, {
      formtastic: {
        labels: {
          fake_model: {
            fake_attr_html: "HTML label"
          }
        }
      }
    })

    localizer = build_localizer_for("fake_model")
    result = localizer.localize(:fake_attr, nil, :label)

    assert_nil result
  ensure
    clear_stored_translations
  end

  test "resolves scoped _html hint key as html_safe" do
    org(basket_i18n_scopes: { "en" => "bag" })

    I18n.backend.store_translations(:en, {
      formtastic: {
        hints: {
          fake_model: {
            "fake_attr/bag_html": "Scoped hint with <a href='/test'>link</a>"
          }
        }
      }
    })

    localizer = build_localizer_for("fake_model")
    result = localizer.localize(:fake_attr, nil, :hint)

    assert_equal "Scoped hint with <a href='/test'>link</a>", result
    assert_predicate result, :html_safe?
  ensure
    clear_stored_translations
  end

  test "returns nil when no hint key exists" do
    localizer = build_localizer_for("fake_model")
    result = localizer.localize(:totally_nonexistent_xyz, nil, :hint)

    assert_nil result
  ensure
    clear_stored_translations
  end

  private

  BuilderStub = Struct.new(:model_name, :object, :template, keyword_init: true) do
    def i18n_lookups_by_default = true
    def i18n_cache_lookups = false
    def escape_html_entities_in_hints_and_labels = false
  end

  TemplateStub = Struct.new(:params, keyword_init: true)

  ModelNameStub = Struct.new(:underscore, keyword_init: true) do
    def to_s = underscore
  end

  def build_localizer_for(model_name, object: nil)
    builder = BuilderStub.new(
      model_name: ModelNameStub.new(underscore: model_name),
      object: object,
      template: TemplateStub.new(params: { action: "edit" })
    )

    Formtastic::HtmlHintLocalizer.new(builder)
  end

  def clear_stored_translations
    I18n.backend.reload!
    Formtastic::HtmlHintLocalizer.cache.clear!
  end
end

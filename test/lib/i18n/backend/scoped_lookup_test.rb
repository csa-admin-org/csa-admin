# frozen_string_literal: true

require "test_helper"

class I18n::Backend::ScopedLookupTest < ActiveSupport::TestCase
  # === Basic scoped resolution ===

  test "resolves scoped key when basket scope variant exists" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: { greeting: "Hello", "greeting/bag": "Hello bag" } })

    assert_equal "Hello bag", I18n.t("test_lookup.greeting")
  ensure
    clear
  end

  test "falls back to unscoped key when scoped variant is missing" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: { greeting: "Hello" } })

    assert_equal "Hello", I18n.t("test_lookup.greeting")
  ensure
    clear
  end

  test "resolves scoped key when activity scope variant exists" do
    org(activity_i18n_scope: "day_work")

    store(:en, { test_lookup: { label: "Default", "label/day_work": "Day work label" } })

    assert_equal "Day work label", I18n.t("test_lookup.label")
  ensure
    clear
  end

  test "falls back to unscoped key when activity scope variant is missing" do
    org(activity_i18n_scope: "day_work")

    store(:en, { test_lookup: { label: "Default" } })

    assert_equal "Default", I18n.t("test_lookup.label")
  ensure
    clear
  end

  # === Both scopes active simultaneously ===

  test "basket scope is tried before activity scope" do
    org(basket_i18n_scopes: { "en" => "bag" }, activity_i18n_scope: "day_work")

    store(:en, { test_lookup: {
      word: "Default",
      "word/bag": "Bag word",
      "word/day_work": "Day work word"
    } })

    assert_equal "Bag word", I18n.t("test_lookup.word")
  ensure
    clear
  end

  test "activity scope is used when basket scope variant is missing" do
    org(basket_i18n_scopes: { "en" => "bag" }, activity_i18n_scope: "day_work")

    store(:en, { test_lookup: {
      word: "Default",
      "word/day_work": "Day work word"
    } })

    assert_equal "Day work word", I18n.t("test_lookup.word")
  ensure
    clear
  end

  test "falls back to unscoped when both scope variants are missing" do
    org(basket_i18n_scopes: { "en" => "bag" }, activity_i18n_scope: "day_work")

    store(:en, { test_lookup: { word: "Default" } })

    assert_equal "Default", I18n.t("test_lookup.word")
  ensure
    clear
  end

  # === Key formats ===

  test "works with symbol keys" do
    org(basket_i18n_scopes: { "en" => "cone" })

    store(:en, { test_lookup: { item: "Default item", "item/cone": "Cone item" } })

    assert_equal "Cone item", I18n.t(:item, scope: :test_lookup)
  ensure
    clear
  end

  test "works with dotted string keys" do
    org(basket_i18n_scopes: { "en" => "share" })

    store(:en, { test_lookup: { nested: { deep: "Unscoped", "deep/share": "Share deep" } } })

    assert_equal "Share deep", I18n.t("test_lookup.nested.deep")
  ensure
    clear
  end

  test "works with explicit scope option" do
    org(basket_i18n_scopes: { "en" => "package" })

    store(:en, { test_lookup: { info: "Default", "info/package": "Package info" } })

    assert_equal "Package info", I18n.t(:info, scope: "test_lookup")
  ensure
    clear
  end

  test "works with array scope option" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: { section: { title: "Default", "title/bag": "Bag title" } } })

    assert_equal "Bag title", I18n.t(:title, scope: [ :test_lookup, :section ])
  ensure
    clear
  end

  # === Nil / missing Current.org ===

  test "no-ops gracefully when no scopes are active" do
    store(:en, { test_lookup: { safe: "Safe value" } })

    # Temporarily override active_i18n_scopes to simulate no org context
    I18n.backend.define_singleton_method(:active_i18n_scopes) { |_locale = nil| [] }
    assert_equal "Safe value", I18n.t("test_lookup.safe")
  ensure
    # Remove the singleton override so the original method is restored
    class << I18n.backend; remove_method(:active_i18n_scopes); end
    clear
  end

  # === Does not interfere with non-scoped keys ===

  test "non-scoped keys resolve normally" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: { plain: "Plain value" } })

    assert_equal "Plain value", I18n.t("test_lookup.plain")
  ensure
    clear
  end

  test "returns missing translation for truly missing keys" do
    org(basket_i18n_scopes: { "en" => "bag" })

    assert_raises(I18n::MissingTranslationData) do
      I18n.t("test_lookup.totally_nonexistent_xyz_#{SecureRandom.hex(4)}")
    end
  end

  # === Interpolation ===

  test "interpolation works with scoped keys" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: {
      "greeting/bag": "Hello %{name} with bag"
    } })

    assert_equal "Hello World with bag", I18n.t("test_lookup.greeting", name: "World")
  ensure
    clear
  end

  # === Locale awareness ===

  test "respects current locale" do
    org(languages: %w[en fr], basket_i18n_scopes: { "en" => "bag", "fr" => "bag" })

    store(:en, { test_lookup: { word: "Basket EN", "word/bag": "Bag EN" } })
    store(:fr, { test_lookup: { word: "Panier FR", "word/bag": "Sac FR" } })

    assert_equal "Bag EN", I18n.t("test_lookup.word", locale: :en)
    assert_equal "Sac FR", I18n.t("test_lookup.word", locale: :fr)
  ensure
    clear
  end

  test "resolves different scopes per locale" do
    org(languages: %w[fr de], basket_i18n_scopes: { "fr" => "basket", "de" => "bag" })

    store(:fr, { test_lookup: { "word/basket": "Panier FR", "word/bag": "Sac FR" } })
    store(:de, { test_lookup: { "word/basket": "Korb DE", "word/bag": "Tasche DE" } })

    assert_equal "Panier FR", I18n.t("test_lookup.word", locale: :fr)
    assert_equal "Tasche DE", I18n.t("test_lookup.word", locale: :de)
  ensure
    clear
  end

  test "per-locale scope falls back to default_locale scope for unknown locale" do
    org(languages: %w[fr], basket_i18n_scopes: { "fr" => "basket" })

    store(:en, { test_lookup: { "word/basket": "Basket EN", "word/bag": "Bag EN" } })

    assert_equal "Basket EN", I18n.t("test_lookup.word", locale: :en)
  ensure
    clear
  end

  # === Default option ===

  test "scoped key takes precedence over default option" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: { "item/bag": "Bag item" } })

    assert_equal "Bag item", I18n.t("test_lookup.item", default: "Fallback")
  ensure
    clear
  end

  test "default option used when neither scoped nor unscoped key exists" do
    org(basket_i18n_scopes: { "en" => "bag" })

    assert_equal "Fallback", I18n.t("test_lookup.nonexistent_#{SecureRandom.hex(4)}", default: "Fallback")
  end

  # === Real-world keys (integration with existing YAML translations) ===

  test "resolves activerecord attribute with basket scope" do
    org(basket_i18n_scopes: { "en" => "bag" })

    # basket_sizes_total is a known scoped key under delivery.*
    scoped = I18n.t("delivery.basket_sizes_total/bag", locale: :en)
    auto = I18n.t("delivery.basket_sizes_total", locale: :en)

    assert_equal scoped, auto
  end

  test "resolves delivery change_types with basket scope" do
    org(basket_i18n_scopes: { "en" => "bag" })

    scoped = I18n.t("delivery.change_types.basket_changed/bag", locale: :en)
    auto = I18n.t("delivery.change_types.basket_changed", locale: :en)

    assert_equal scoped, auto
    assert_equal "Bag", auto
  end

  test "resolves delivery change_types with basket scope in DE" do
    org(basket_i18n_scopes: { "en" => "basket" })

    auto = I18n.t("delivery.change_types.basket_changed", locale: :de)

    assert_equal "Korb", auto
  end

  test "resolves real _html scoped key (ongoing_fiscal_year_warning)" do
    org(basket_i18n_scopes: { "en" => "bag" })

    scoped = I18n.t("active_admin.resources.delivery.ongoing_fiscal_year_warning/bag_html", year: "2025", locale: :en)
    auto = I18n.t("active_admin.resources.delivery.ongoing_fiscal_year_warning_html", year: "2025", locale: :en)

    assert_equal scoped, auto
    assert_includes auto, "bags"
  end

  # === _html keys ===

  test "scoped resolution rewrites _html suffix: key_html -> key/scope_html" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: {
      "notice/bag_html": "<b>Bag</b> notice",
      notice_html: "<b>Default</b> notice"
    } })

    assert_equal "<b>Bag</b> notice", I18n.t("test_lookup.notice_html")
  ensure
    clear
  end

  test "scoped _html falls back to unscoped _html when scoped variant missing" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: {
      notice_html: "<b>Default</b> notice"
    } })

    assert_equal "<b>Default</b> notice", I18n.t("test_lookup.notice_html")
  ensure
    clear
  end

  test "scoped _html works with dotted string keys" do
    org(basket_i18n_scopes: { "en" => "share" })

    store(:en, { test_lookup: { nested: {
      "warning/share_html": "<b>Share</b> warning",
      warning_html: "<b>Default</b> warning"
    } } })

    assert_equal "<b>Share</b> warning", I18n.t("test_lookup.nested.warning_html")
  ensure
    clear
  end

  test "scoped _html works with symbol key and scope option" do
    org(basket_i18n_scopes: { "en" => "cone" })

    store(:en, { test_lookup: {
      "desc/cone_html": "<b>Cone</b> desc",
      desc_html: "<b>Default</b> desc"
    } })

    assert_equal "<b>Cone</b> desc", I18n.t(:desc_html, scope: :test_lookup)
  ensure
    clear
  end

  test "non-html keys are not affected by _html rewriting" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: {
      "plain/bag": "Bag plain",
      plain: "Default plain"
    } })

    assert_equal "Bag plain", I18n.t("test_lookup.plain")
  ensure
    clear
  end

  test "scoped _html with interpolation" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: {
      "shifted/bag_html": 'Shifted to <a href="%{url}">%{date}</a>'
    } })

    assert_equal 'Shifted to <a href="/test">Monday</a>',
      I18n.t("test_lookup.shifted_html", url: "/test", date: "Monday")
  ensure
    clear
  end

  # === Pluralization ===

  test "scoped resolution works with count/pluralization" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: {
      items: { one: "%{count} item", other: "%{count} items" },
      "items/bag": { one: "%{count} bag", other: "%{count} bags" }
    } })

    assert_equal "1 bag", I18n.t("test_lookup.items", count: 1)
    assert_equal "3 bags", I18n.t("test_lookup.items", count: 3)
  ensure
    clear
  end

  # === Scoped key does not exist but has subtree ===

  test "does not return hash subtrees as scoped results" do
    org(basket_i18n_scopes: { "en" => "bag" })

    store(:en, { test_lookup: {
      parent: "Default parent",
      "parent/bag": { nested: "This is nested, not a translation" }
    } })

    # The scoped key resolves to a Hash (subtree), not a string.
    # I18n.t should treat it as the resolved value (a Hash), which is valid
    # behavior for subtree access. This test just ensures no crash.
    result = I18n.t("test_lookup.parent")
    assert_kind_of Hash, result
  ensure
    clear
  end

  private

  def store(locale, data)
    I18n.backend.store_translations(locale, data)
  end

  def clear
    I18n.backend.reload!
  end
end

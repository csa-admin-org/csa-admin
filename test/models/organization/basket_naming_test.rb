# frozen_string_literal: true

require "test_helper"

class Organization::BasketNamingTest < ActiveSupport::TestCase
  test "basket_i18n_scopes has default values from migration" do
    org = organizations(:acme)

    assert_equal "basket", org.basket_i18n_scopes["en"]
  end

  test "basket_i18n_scopes setter accepts a hash" do
    org = organizations(:acme)
    org.basket_i18n_scopes = { "en" => "basket", "de" => "bag" }

    assert_equal({ "en" => "basket", "de" => "bag" }, org.basket_i18n_scopes)
    assert org.valid?
  end

  test "basket_i18n_scopes setter accepts a string and expands to all org languages" do
    org = organizations(:acme)
    org.basket_i18n_scopes = "bag"

    org.languages.each do |locale|
      assert_equal "bag", org.basket_i18n_scopes[locale]
    end
    assert org.valid?
  end

  test "basket_i18n_scopes setter strips blank values from hash" do
    org = organizations(:acme)
    org.basket_i18n_scopes = { "en" => "basket", "de" => "" }

    assert_equal({ "en" => "basket" }, org.basket_i18n_scopes)
  end

  test "basket_i18n_scopes must contain valid scope values" do
    org = organizations(:acme)

    Organization::BasketNaming::BASKET_I18N_SCOPES.each do |scope|
      org.basket_i18n_scopes = { "en" => scope }
      assert org.valid?, "expected #{scope.inspect} to be valid"
    end

    org.basket_i18n_scopes = { "en" => "invalid" }
    assert_not org.valid?
  end

  test "basket_i18n_scope_for returns scope for given locale" do
    org = organizations(:acme)
    org.update!(languages: %w[fr de])
    org.basket_i18n_scopes = { "fr" => "basket", "de" => "bag" }

    assert_equal "basket", org.basket_i18n_scope_for(:fr)
    assert_equal "bag", org.basket_i18n_scope_for(:de)
  end

  test "basket_i18n_scope_for falls back to default_locale scope for missing language" do
    org = organizations(:acme)
    org.update!(languages: %w[fr de])
    org.basket_i18n_scopes = { "fr" => "basket" }

    assert_equal "basket", org.basket_i18n_scope_for(:de)
  end

  test "basket_i18n_scope_for normalizes locale not in org languages to default_locale" do
    org = organizations(:acme)
    org.basket_i18n_scopes = { "en" => "bag" }

    assert_equal "bag", org.basket_i18n_scope_for(:de)
  end

  test "basket_i18n_scope_for falls back to first scope constant when nothing matches" do
    org = organizations(:acme)
    org.basket_i18n_scopes = {}

    assert_equal "basket", org.basket_i18n_scope_for(:en)
  end

  test "per-locale virtual setters write into the hash" do
    org = organizations(:acme)
    org.basket_i18n_scope_en = "bag"

    assert_equal "bag", org.basket_i18n_scopes["en"]
  end

  test "per-locale virtual setter with blank removes the locale" do
    org = organizations(:acme)
    org.basket_i18n_scopes = { "en" => "basket", "fr" => "bag" }
    org.basket_i18n_scope_fr = ""

    assert_nil org.basket_i18n_scopes["fr"]
  end

  test "basket_i18n_scopes class method returns all scopes" do
    assert_equal %w[basket bag share package cone], Organization.basket_i18n_scopes
  end
end

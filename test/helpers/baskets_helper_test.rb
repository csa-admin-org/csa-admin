# frozen_string_literal: true

require "test_helper"

class BasketsHelperTest < ActionView::TestCase
  def set_basket_scope(scope)
    scopes = Current.org.languages.index_with { scope }
    Current.org.update_column(:basket_i18n_scopes, scopes)
    Current.org.reload
  end

  test "Basket.model_name.human returns singular name for default scope" do
    set_basket_scope("basket")

    I18n.with_locale(:en) do
      assert_equal "Basket", Basket.model_name.human
    end

    I18n.with_locale(:fr) do
      assert_equal "Panier", Basket.model_name.human
    end
  end

  test "Basket.model_name.human(count: 2) returns plural name for default scope" do
    set_basket_scope("basket")

    I18n.with_locale(:en) do
      assert_equal "Baskets", Basket.model_name.human(count: 2)
    end

    I18n.with_locale(:fr) do
      assert_equal "Paniers", Basket.model_name.human(count: 2)
    end
  end

  test "Basket.model_name.human returns correct name for bag scope" do
    set_basket_scope("bag")

    I18n.with_locale(:en) do
      assert_equal "Bag", Basket.model_name.human
    end

    I18n.with_locale(:de) do
      assert_equal "Tasche", Basket.model_name.human
    end
  end

  test "Basket.model_name.human(count: 2) returns correct name for bag scope" do
    set_basket_scope("bag")

    I18n.with_locale(:en) do
      assert_equal "Bags", Basket.model_name.human(count: 2)
    end

    I18n.with_locale(:de) do
      assert_equal "Taschen", Basket.model_name.human(count: 2)
    end
  end

  test "Basket.model_name.human returns correct name for each scope in EN" do
    {
      "basket" => "Basket",
      "bag" => "Bag",
      "share" => "Share",
      "package" => "Package",
      "cone" => "Cone"
    }.each do |scope, expected|
      set_basket_scope(scope)
      I18n.with_locale(:en) do
        assert_equal expected, Basket.model_name.human, "expected #{expected} for scope #{scope}"
      end
    end
  end

  test "BasketContent.model_name.human returns singular compound name" do
    set_basket_scope("basket")

    I18n.with_locale(:en) do
      assert_equal "Basket content", BasketContent.model_name.human
    end

    I18n.with_locale(:de) do
      assert_equal "Korbinhalt", BasketContent.model_name.human
    end
  end

  test "BasketContent.model_name.human(count: 2) returns plural compound name" do
    set_basket_scope("bag")

    I18n.with_locale(:en) do
      assert_equal "Bag contents", BasketContent.model_name.human(count: 2)
    end

    I18n.with_locale(:de) do
      assert_equal "Tascheninhalte", BasketContent.model_name.human(count: 2)
    end
  end

  test "BasketSize.model_name.human returns singular compound name" do
    set_basket_scope("basket")

    I18n.with_locale(:en) do
      assert_equal "Basket size", BasketSize.model_name.human
    end

    I18n.with_locale(:de) do
      assert_equal "Korbgrösse", BasketSize.model_name.human
    end
  end

  test "BasketSize.model_name.human(count: 2) returns plural compound name" do
    set_basket_scope("share")

    I18n.with_locale(:en) do
      assert_equal "Share sizes", BasketSize.model_name.human(count: 2)
    end

    I18n.with_locale(:de) do
      assert_equal "Anteilsgrössen", BasketSize.model_name.human(count: 2)
    end
  end

  test "BasketComplement.model_name.human returns singular compound name" do
    set_basket_scope("basket")

    I18n.with_locale(:en) do
      assert_equal "Basket complement", BasketComplement.model_name.human
    end

    I18n.with_locale(:fr) do
      assert_equal "Complément panier", BasketComplement.model_name.human
    end
  end

  test "BasketComplement.model_name.human(count: 2) returns plural compound name" do
    set_basket_scope("cone")

    I18n.with_locale(:en) do
      assert_equal "Cone complements", BasketComplement.model_name.human(count: 2)
    end

    I18n.with_locale(:fr) do
      assert_equal "Compléments cornet", BasketComplement.model_name.human(count: 2)
    end
  end

  test "all scopes have complete model name translations for all languages" do
    locales = %i[en fr de it nl]
    models = [ Basket, BasketContent, BasketSize, BasketComplement ]

    Organization::BasketNaming::BASKET_I18N_SCOPES.each do |scope|
      set_basket_scope(scope)
      models.each do |model|
        locales.each do |locale|
          I18n.with_locale(locale) do
            singular = model.model_name.human
            assert singular.present?,
              "Missing singular model name for #{model} with scope #{scope} in #{locale}"

            plural = model.model_name.human(count: 2)
            assert plural.present?,
              "Missing plural model name for #{model} with scope #{scope} in #{locale}"
          end
        end
      end
    end
  end

  test "every scope produces distinct translations per language" do
    locales = %i[en fr de it nl]
    scopes = Organization::BasketNaming::BASKET_I18N_SCOPES

    locales.each do |locale|
      I18n.with_locale(locale) do
        singular_names = scopes.map { |s|
          set_basket_scope(s)
          Basket.model_name.human
        }
        assert_equal singular_names.uniq.size, singular_names.size,
          "Duplicate singular basket names found in #{locale}: #{singular_names.inspect}"

        plural_names = scopes.map { |s|
          set_basket_scope(s)
          Basket.model_name.human(count: 2)
        }
        assert_equal plural_names.uniq.size, plural_names.size,
          "Duplicate plural basket names found in #{locale}: #{plural_names.inspect}"
      end
    end
  end
end

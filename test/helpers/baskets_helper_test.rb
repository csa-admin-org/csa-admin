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

  test "basket_admin_shift_targets_collection is a flat list ordered by delivery date" do
    travel_to "2024-04-01"
    org(features: [ :absence ], absences_billed: true)

    source = baskets(:jane_3)
    collection = basket_admin_shift_targets_collection(source)
    values = collection.map { |_, value,| value }
    dates = values.map { |value| shift_target_option_date(value) }

    assert collection.none? { |_, value,| value.is_a?(Array) }
    assert_equal dates, dates.sort
    assert_includes values, baskets(:jane_1).id
    assert_includes values, baskets(:jane_5).id
    assert_includes values, "delivery:#{deliveries(:monday_1).id}"
    assert_includes values, "delivery:#{deliveries(:monday_2).id}"
    assert_not_includes values, source.id

    absent = collection.find { |_, value,| value == baskets(:jane_5).id }
    assert absent.last[:disabled]
    assert dates.index(deliveries(:monday_1).date) < dates.index(baskets(:jane_1).delivery.date)
    assert dates.index(baskets(:jane_1).delivery.date) < dates.index(deliveries(:monday_2).date)
    assert dates.index(deliveries(:monday_2).date) < dates.index(baskets(:jane_2).delivery.date)
    assert dates.index(baskets(:jane_4).delivery.date) < dates.index(baskets(:jane_5).delivery.date)
  end

  test "basket_shift_form_collection keeps declined first for an absent basket" do
    travel_to "2024-04-01"
    org(features: [ :absence ], absences_billed: true)

    collection = basket_shift_form_collection(baskets(:jane_5))
    dates = collection.drop(1).map { |_, value,| shift_target_option_date(value) }

    assert_equal :declined, collection.first.second
    assert_equal dates, dates.sort
    assert_includes dates, deliveries(:monday_1).date
  end

  test "basket_shift_form_collection omits declined without an absence" do
    travel_to "2024-04-01"
    org(features: [ :absence ], absences_billed: true)

    collection = basket_shift_form_collection(baskets(:jane_3))

    assert collection.none? { |_, value,| value == :declined }
    assert_equal basket_admin_shift_targets_collection(baskets(:jane_3)), collection
  end

  private

  def shift_target_option_date(value)
    if value.to_s.start_with?("delivery:")
      Delivery.find(value.to_s.delete_prefix("delivery:")).date
    else
      Basket.find(value).delivery.date
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class BasketPriceExtraFeatureTest < ActiveSupport::TestCase
  test "default_basket_price_extra_labels returns labels for all languages" do
    org = organizations(:acme)
    labels = org.default_basket_price_extra_labels

    assert_equal Organization::LANGUAGES, labels.keys
  end

  test "default_basket_price_extra_labels contains valid Liquid syntax" do
    org = organizations(:acme)
    labels = org.default_basket_price_extra_labels

    labels.each_value do |label|
      assert_nothing_raised do
        Liquid::Template.parse(label)
      end
    end
  end

  test "default_basket_price_extra_labels uses translated base_price" do
    org = organizations(:acme)
    labels = org.default_basket_price_extra_labels

    assert_includes labels["en"], "Base price"
    assert_includes labels["fr"], "Tarif de base"
  end

  test "default_basket_price_extra_labels uses translated basket" do
    org = organizations(:acme)
    labels = org.default_basket_price_extra_labels

    assert_includes labels["en"], "/basket"
    assert_includes labels["fr"], "/panier"
  end

  test "default_basket_price_extra_labels renders correctly with Liquid" do
    org = organizations(:acme)
    labels = org.default_basket_price_extra_labels

    template = Liquid::Template.parse(labels["en"])

    result_zero = template.render("extra" => 0)
    assert_includes result_zero, "Base price"

    result_decimal = template.render("extra" => 1.5)
    assert_includes result_decimal, "+ 1.5/basket"

    result_integer = template.render("extra" => 3)
    assert_includes result_integer, "+ 3.-/basket"
  end

  test "default_basket_price_extra_label_details returns details for all languages" do
    org = organizations(:acme)
    details = org.default_basket_price_extra_label_details

    assert_equal Organization::LANGUAGES, details.keys
  end

  test "default_basket_price_extra_label_details returns expected Liquid template" do
    org = organizations(:acme)
    details = org.default_basket_price_extra_label_details

    details.each_value do |detail|
      assert_equal "{% if extra != 0 %}{{ full_year_price }}{% endif %}", detail
    end
  end

  test "set_basket_price_extra_defaults sets label_details on create" do
    org = Organization.new
    org.send(:set_basket_price_extra_defaults)

    assert_equal org.default_basket_price_extra_label_details, org.basket_price_extra_label_details
  end

  test "basket_price_extras? returns true when extras are configured" do
    org = organizations(:acme)
    org[:basket_price_extras] = [ 0, 1, 2 ]

    assert org.basket_price_extras?
  end

  test "basket_price_extras? returns false when no extras configured" do
    org = organizations(:acme)
    org[:basket_price_extras] = []

    assert_not org.basket_price_extras?
  end

  test "basket_price_extras= parses comma-separated string" do
    org = organizations(:acme)
    org.basket_price_extras = "0, 1.5, 2, 3"

    assert_equal [ 0.0, 1.5, 2.0, 3.0 ], org[:basket_price_extras]
  end

  test "basket_price_extras returns comma-separated string" do
    org = organizations(:acme)
    org[:basket_price_extras] = [ 0, 1.5, 2 ]

    assert_equal "0, 1.5, 2", org.basket_price_extras
  end

  test "calculate_basket_price_extra returns extra when no dynamic pricing" do
    org = organizations(:acme)
    org.basket_price_extra_dynamic_pricing = nil

    assert_equal 2.5, org.calculate_basket_price_extra(2.5, 30, 1, 5, 40)
  end

  test "calculate_basket_price_extra evaluates dynamic pricing formula" do
    org = organizations(:acme)
    org.basket_price_extra_dynamic_pricing = "{{ extra | times: basket_size_price | divided_by: 30 }}"

    result = org.calculate_basket_price_extra(2, 60, 1, 5, 40)
    assert_equal 4.0, result
  end
end

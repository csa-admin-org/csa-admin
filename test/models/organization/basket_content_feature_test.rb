# frozen_string_literal: true

require "test_helper"

class BasketContentFeatureTest < ActiveSupport::TestCase
  test "basket_content_member_title returns value for current locale" do
    org = organizations(:acme)

    assert_equal org[:basket_content_member_titles][I18n.locale.to_s], org.basket_content_member_title
  end

  test "basket_content_member_title uses custom value when set" do
    org = organizations(:acme)
    org[:basket_content_member_titles] = { I18n.locale.to_s => "Custom Title" }

    assert_equal "Custom Title", org.basket_content_member_title
  end

  test "validates basket_content_member_title presence" do
    org = organizations(:acme)
    org[:basket_content_member_titles] = {}

    assert_not org.valid?
    assert_not_empty org.errors[:basket_content_member_title_en]
  end

  test "basket_content_member_visible? returns false by default" do
    org = organizations(:acme)

    assert_not org.basket_content_member_visible?
  end

  test "basket_content_member_visible? returns true when enabled" do
    org = organizations(:acme)
    org.basket_content_member_visible = true

    assert org.basket_content_member_visible?
  end

  test "basket_content_member_display_quantity? returns true by default" do
    org = organizations(:acme)

    assert org.basket_content_member_display_quantity?
  end

  test "validates basket_content_member_visible_hours_before is not negative" do
    org = organizations(:acme)
    org.basket_content_member_visible_hours_before = -1

    assert_not org.valid?
    assert_includes org.errors[:basket_content_member_visible_hours_before], "must be greater than or equal to 0"
  end

  test "validates basket_content_member_visible_hours_before allows zero" do
    org = organizations(:acme)
    org.basket_content_member_visible_hours_before = 0

    org.valid?

    assert_empty org.errors[:basket_content_member_visible_hours_before]
  end

  test "basket_content_member_visible_at calculates correctly" do
    org = organizations(:acme)
    org.basket_content_member_visible_hours_before = 24

    delivery = Delivery.new(date: Date.new(2026, 3, 15))
    visible_at = org.basket_content_member_visible_at(delivery)

    expected = Date.new(2026, 3, 15).in_time_zone(org.time_zone).beginning_of_day - 24.hours
    assert_equal expected, visible_at
  end

  test "basket_content_member_visible_at with zero hours" do
    org = organizations(:acme)
    org.basket_content_member_visible_hours_before = 0

    delivery = Delivery.new(date: Date.new(2026, 3, 15))
    visible_at = org.basket_content_member_visible_at(delivery)

    expected = Date.new(2026, 3, 15).in_time_zone(org.time_zone).beginning_of_day
    assert_equal expected, visible_at
  end

  test "basket_content_visible_for_delivery? returns false when not enabled" do
    org = organizations(:acme)
    org.basket_content_member_visible = false

    delivery = Delivery.new(date: Date.current)

    assert_not org.basket_content_visible_for_delivery?(delivery)
  end

  test "basket_content_visible_for_delivery? returns true when within time window" do
    org = organizations(:acme)
    org.basket_content_member_visible = true
    org.basket_content_member_visible_hours_before = 24

    delivery = Delivery.new(date: Date.current)

    travel_to Date.current.in_time_zone(org.time_zone).beginning_of_day do
      assert org.basket_content_visible_for_delivery?(delivery)
    end
  end

  test "basket_content_visible_for_delivery? returns true when exactly at visible_at time" do
    org = organizations(:acme)
    org.basket_content_member_visible = true
    org.basket_content_member_visible_hours_before = 24

    delivery = Delivery.new(date: Date.new(2026, 3, 15))
    visible_at = org.basket_content_member_visible_at(delivery)

    travel_to visible_at + 1.second do
      assert org.basket_content_visible_for_delivery?(delivery)
    end
  end

  test "basket_content_visible_for_delivery? returns false when before time window" do
    org = organizations(:acme)
    org.basket_content_member_visible = true
    org.basket_content_member_visible_hours_before = 24

    delivery = Delivery.new(date: Date.new(2026, 3, 15))
    visible_at = org.basket_content_member_visible_at(delivery)

    travel_to visible_at - 1.second do
      assert_not org.basket_content_visible_for_delivery?(delivery)
    end
  end

  test "default_basket_content_member_titles returns titles for all languages" do
    org = organizations(:acme)
    titles = org.default_basket_content_member_titles

    assert_equal Organization::LANGUAGES, titles.keys
  end

  test "default_basket_content_member_titles contains expected content" do
    org = organizations(:acme)
    titles = org.default_basket_content_member_titles

    assert_equal "Your basket contents", titles["en"]
    assert_equal "Contenu de votre panier", titles["fr"]
  end

  test "default_basket_content_member_notes returns notes for all languages" do
    org = organizations(:acme)
    notes = org.default_basket_content_member_notes

    assert_equal Organization::LANGUAGES, notes.keys
  end

  test "default_basket_content_member_notes contains expected content" do
    org = organizations(:acme)
    notes = org.default_basket_content_member_notes

    assert_includes notes["en"], "No guarantee, last-minute changes are possible"
    assert_includes notes["fr"], "Sans garantie, des changements de dernière minute sont possibles"
  end

  test "set_basket_content_member_defaults sets titles and notes on create" do
    org = Organization.new
    org.send(:set_basket_content_member_defaults)

    assert_equal org.default_basket_content_member_titles, org.read_attribute(:basket_content_member_titles)
    assert_equal org.default_basket_content_member_notes, org.read_attribute(:basket_content_member_notes)
  end
end

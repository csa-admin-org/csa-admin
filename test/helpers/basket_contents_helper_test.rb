# frozen_string_literal: true

require "test_helper"

class BasketContentsHelperTest < ActionView::TestCase
  test "unit suffix helpers return per-size and total suffixes" do
    assert_equal "g", basket_content_unit_suffix("kg")
    assert_equal "kg", basket_content_total_unit_suffix("kg")
    pc_suffix = I18n.t("units.pc_quantity", quantity: "").strip
    assert_equal pc_suffix, basket_content_unit_suffix("pc")
    assert_equal pc_suffix, basket_content_total_unit_suffix("pc")
  end

  test "basket content totals sum display quantities and each content price" do
    first = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg",
      unit_price: 2)
    second = create_basket_content(
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: { medium_id => 1000 },
      unit: "kg",
      unit_price: 3)

    totals = basket_contents_totals([ first, second ])

    assert_equal BigDecimal("2.3"), totals[:quantity]
    assert_equal BigDecimal("5.5"), totals[:price]
  end

  test "basket content total quantity display keeps kg totals in kg" do
    assert_equal I18n.t("units.kg_quantity", quantity: "0"),
      display_basket_contents_total_quantity(0, "kg")
  end

  test "form percentages use saved quantities or pro-rated defaults" do
    new_content = BasketContent.new(unit: "kg")
    assert_equal new_content.basket_size_ids_percentages_pro_rated,
      basket_content_form_percentages(new_content)

    content = build_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg")
    assert_equal({ small_id => 40, medium_id => 60 }, basket_content_form_percentages(content))
  end

  test "products collection shows plain name without sibling" do
    product = basket_content_products(:carrots)

    name, _, _ = basket_content_products_collection.find { |(_, id, _)| id == product.id }
    assert_equal "Carrots", name
  end

  test "products collection shows name with unit when sibling exists" do
    product = basket_content_products(:carrots)
    BasketContent::Product.create!(names: product[:names], unit: "pc")

    name, _, _ = basket_content_products_collection.find { |(_, id, _)| id == product.id }
    assert_equal "Carrots (#{I18n.t('units.kg.short')})", name
  end

  test "products collection does not expose product defaults as data attributes" do
    product = basket_content_products(:carrots)
    product.update!(default_price: 3.25, default_basket_quantities: { small_id.to_s => 500 })

    _, _, options = basket_content_products_collection.find { |(_, id, _)| id == product.id }

    refute_includes options[:data], :latest_basket_content_unit_price
    refute_includes options[:data], :latest_basket_content_quantities
    refute_includes options[:data], :unit
  end

  # display_depots

  test "display_depots returns 'all' when all depots are selected" do
    assert_equal I18n.t("basket_content.depots.all"), display_depots(Depot.kept)
  end

  test "display_depots returns depot name when only one depot is selected" do
    assert_equal depots(:farm).name, display_depots(Depot.where(id: depots(:farm).id))
  end

  test "display_depots uses group name when all depots of a group are excluded" do
    group = DepotGroup.create!(names: { en: "Tournée" })
    depots(:farm).update!(group: group)
    depots(:bakery).update!(group: group)
    # home stays ungrouped; extra ensures selected set has 2 depots (avoids single-depot shortcut)
    extra = Depot.create!(names: { en: "Extra" }, language: "en", price: 0, position: 99)

    selected = Depot.kept.where(id: [ depots(:home).id, extra.id ])
    assert_equal I18n.t("basket_content.depots.all_but", missing: group.name),
      display_depots(selected)
  end

  test "display_depots uses group name when only one group is selected" do
    group = DepotGroup.create!(names: { en: "Tournée" })
    depots(:farm).update!(group: group)
    depots(:bakery).update!(group: group)
    # extra ensures 2 depots are missing (avoids single-missing shortcut)
    Depot.create!(names: { en: "Extra" }, language: "en", price: 0, position: 99)

    selected = Depot.kept.where(id: [ depots(:farm).id, depots(:bakery).id ])
    assert_equal I18n.t("basket_content.depots.only", selected: group.name),
      display_depots(selected)
  end

  test "display_depots returns depot name when the single missing depot belongs to a group" do
    group = DepotGroup.create!(names: { en: "Tournée" })
    depots(:farm).update!(group: group)
    # single-missing check fires before group logic, so the depot name is used
    selected = Depot.kept.where.not(id: depots(:farm).id)
    assert_equal I18n.t("basket_content.depots.all_but", missing: depots(:farm).name),
      display_depots(selected)
  end

  test "display_depots falls back to depot names when only part of a group is selected" do
    group = DepotGroup.create!(names: { en: "Tournée" })
    depots(:farm).update!(group: group)
    depots(:bakery).update!(group: group)
    # extra gives us 4 depots total so selecting 2 doesn't hit single-missing
    extra = Depot.create!(names: { en: "Extra" }, language: "en", price: 0, position: 99)

    # Only one of the two group depots selected — no clean group match, falls back to "all but" with depot names
    selected = Depot.kept.where(id: [ depots(:farm).id, depots(:home).id ])
    assert_equal I18n.t("basket_content.depots.all_but",
      missing: [ depots(:bakery).name, extra.name ].to_sentence),
      display_depots(selected)
  end

  test "display_depots returns 'all but X' when one depot is missing" do
    all_but_farm = Depot.kept.where.not(id: depots(:farm).id)
    assert_equal I18n.t("basket_content.depots.all_but", missing: depots(:farm).name),
      display_depots(all_but_farm)
  end

  test "display_depots returns 'all but X and Y' when two depots are missing" do
    # extra ensures 2 depots remain selected so single-depot shortcut doesn't fire
    Depot.create!(names: { en: "Extra" }, language: "en", price: 0, position: 99)
    missing = [ depots(:farm), depots(:home) ]
    selected = Depot.kept.where.not(id: missing.map(&:id))
    assert_equal I18n.t("basket_content.depots.all_but",
      missing: missing.map(&:name).to_sentence),
      display_depots(selected)
  end

  test "display_depots lists depot names when more than 2 are missing and no group matches" do
    # Add 2 extra depots so we have 5 total and can select only 2
    Depot.create!(names: { en: "Extra 1" }, language: "en", price: 0, position: 10)
    Depot.create!(names: { en: "Extra 2" }, language: "en", price: 0, position: 11)

    selected = Depot.kept.where(id: [ depots(:farm).id, depots(:home).id ])
    assert_equal [ depots(:farm).name, depots(:home).name ].to_sentence,
      display_depots(selected)
  end
end

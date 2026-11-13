# frozen_string_literal: true

require "test_helper"

class BasketContentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2022-04-01"
    host! "admin.acme.test"
    login admins(:super)
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "index shows total sidebar with product filter and no delivery filter" do
    product = basket_content_products(:carrots)
    create_basket_content(
      product: product,
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg",
      unit_price: 2)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: { medium_id => 1000 },
      unit: "kg",
      unit_price: 3)

    get basket_contents_path(q: { product_id_eq: product.id })

    assert_response :success
    assert_includes response.body, BasketContent.human_attribute_name(:basket_quantity)
    assert_includes response.body, I18n.t("units.kg_quantity", quantity: "2.3")
    assert_includes response.body, "5.50"
  end

  test "index uses delivery date as secondary product ordering" do
    product = basket_content_products(:carrots)
    earlier_delivery = deliveries(:monday_1)
    later_delivery = deliveries(:monday_2)
    create_basket_content(product: product, delivery: later_delivery)
    create_basket_content(product: product, delivery: earlier_delivery)

    get basket_contents_path(
      q: { product_id_eq: product.id },
      order: "product_name_asc")

    assert_response :success
    assert_equal [ earlier_delivery, later_delivery ].map { |delivery|
      I18n.l(delivery.date, format: :number)
    }, delivery_dates

    get basket_contents_path(
      q: { product_id_eq: product.id },
      order: "product_name_desc")

    assert_response :success
    assert_equal [ later_delivery, earlier_delivery ].map { |delivery|
      I18n.l(delivery.date, format: :number)
    }, delivery_dates
  end

  test "csv of a cleared delivery filter is the whole fiscal year" do
    product = basket_content_products(:carrots)
    create_basket_content(product: product, delivery: deliveries(:monday_1))
    create_basket_content(product: product, delivery: deliveries(:monday_2))
    create_basket_content(product: product, delivery: deliveries(:monday_future_1))
    year = deliveries(:monday_1).fy_year
    hint = I18n.t("active_admin.resources.basket_content.csv_fiscal_year_hint",
      delivery: Delivery.model_name.human)

    get basket_contents_path(q: { delivery_id_eq: deliveries(:monday_1).id })

    assert_response :success
    assert_select ".download-hint", text: hint
    assert_select ".paginated-collection-footer a[href*='.xlsx']", text: "XLSX"

    get basket_contents_path(q: { during_year: year })

    assert_response :success
    assert_select ".download-hint", text: hint, count: 0
    assert_select ".paginated-collection-footer a[href*='.xlsx']", count: 0
    assert_select ".paginated-collection-footer a[href*='.csv']" do |links|
      assert_not_includes links.first["href"], "delivery_id_eq"
    end
    assert_includes delivery_dates, I18n.l(deliveries(:monday_1).date, format: :number)
    assert_includes delivery_dates, I18n.l(deliveries(:monday_2).date, format: :number)
    assert_not_includes delivery_dates, I18n.l(deliveries(:monday_future_1).date, format: :number)

    get basket_contents_path(q: { during_year: year }, format: :csv)

    assert_response :success
    assert_includes response.body, deliveries(:monday_1).date.to_s
    assert_includes response.body, deliveries(:monday_2).date.to_s
    assert_not_includes response.body, deliveries(:monday_future_1).date.to_s

    get basket_contents_path(q: { delivery_id_eq: deliveries(:monday_1).id }, format: :csv)

    assert_response :success
    assert_includes response.body, deliveries(:monday_1).date.to_s
    assert_not_includes response.body, deliveries(:monday_2).date.to_s
  end

  test "csv export keeps counts, prices, and depot labels" do
    baskets(:bob_1).update_column(:quantity, 4)
    baskets(:john_1).update_column(:quantity, 2)
    baskets(:anna_1).update_column(:state, "absent")
    baskets(:john_2).update_column(:quantity, 5)
    group = DepotGroup.create!(names: { "en" => "Tour" })
    depots(:farm).update!(group: group)
    depots(:bakery).update!(group: group)
    Depot.create!(names: { "en" => "Extra" }, language: "en", price: 0, position: 99)
    basket_content_products(:cucumbers).update!(producer: producers(:farm))

    year = deliveries(:monday_1).fy_year
    all_depots = create_basket_content(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:carrots),
      depots: Depot.kept.to_a,
      basket_size_ids_quantities: { small_id => 500, medium_id => 250 },
      unit: "kg",
      unit_price: 2)
    grouped = create_basket_content(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:cucumbers),
      depots: [ depots(:farm), depots(:bakery) ],
      basket_size_ids_quantities: { small_id => 1, medium_id => 3 },
      unit: "pc",
      unit_price: 3)
    later = create_basket_content(
      delivery: deliveries(:monday_2),
      product: basket_content_products(:carrots),
      depots: [ depots(:farm) ],
      basket_size_ids_quantities: { medium_id => 1000 },
      unit: "kg",
      unit_price: 4)
    only_tour = I18n.t("basket_content.depots.only", selected: group.name)

    get basket_contents_path(q: { during_year: year })

    assert_response :success
    assert_select "td", text: "All"
    assert_select "td", text: "Farm"
    assert_select "td", text: only_tour

    fiscal_year_rows = [
      basket_content_csv_row(all_depots, counts: { "Small" => "4", "Medium" => "2", "Large" => "0" },
        quantities: { "Small" => "0.5", "Medium" => "0.25", "Large" => "0" },
        prices: { "Small" => money(1), "Medium" => money(0.5), "Large" => money(0) },
        depots: "All"),
      basket_content_csv_row(grouped, counts: { "Small" => "0", "Medium" => "2", "Large" => "0" },
        quantities: { "Small" => "1.0", "Medium" => "3.0", "Large" => "0" },
        prices: { "Small" => money(3), "Medium" => money(9), "Large" => money(0) },
        depots: only_tour),
      basket_content_csv_row(later, counts: { "Small" => "0", "Medium" => "5", "Large" => "0" },
        quantities: { "Small" => "0", "Medium" => "1.0", "Large" => "0" },
        prices: { "Small" => money(0), "Medium" => money(4), "Large" => money(0) },
        depots: "Farm")
    ]

    get basket_contents_path(q: { during_year: year }, format: :csv)

    assert_response :success
    assert_equal expected_basket_contents_csv(fiscal_year_rows).b, response.body.b

    get basket_contents_path(q: { delivery_id_eq: deliveries(:monday_1).id }, format: :csv)

    assert_response :success
    assert_equal expected_basket_contents_csv(fiscal_year_rows.first(2)).b, response.body.b
  end

  test "csv queries do not grow with the number of basket contents" do
    group = DepotGroup.create!(names: { "en" => "Tour" })
    depots(:farm).update!(group: group)
    depots(:bakery).update!(group: group)
    Depot.create!(names: { "en" => "Extra" }, language: "en", price: 0, position: 99)
    basket_content_products(:cucumbers).update!(producer: producers(:farm))
    year = deliveries(:monday_1).fy_year

    seed_csv_basket_contents!
    # Warm the process once so the two measured exports are comparable.
    get basket_contents_path(q: { during_year: year }, format: :csv)
    assert_response :success

    few = collect_sql_queries {
      get basket_contents_path(q: { during_year: year }, format: :csv)
    }
    assert_response :success
    few_body = response.body
    assert_csv_export_queries_bounded(few)

    12.times do |i|
      delivery = deliveries(:"monday_#{(i % 8) + 1}")
      create_basket_content(
        delivery: delivery,
        product: i.even? ? basket_content_products(:carrots) : basket_content_products(:cucumbers),
        depots: i % 3 == 0 ? Depot.kept.to_a : [ depots(:farm), depots(:bakery) ],
        basket_size_ids_quantities: { small_id => i.even? ? 200 : 1, medium_id => i.even? ? 400 : 2 },
        unit_price: 1.5)
    end

    many = collect_sql_queries {
      get basket_contents_path(q: { during_year: year }, format: :csv)
    }
    assert_response :success
    assert_csv_export_queries_bounded(many)
    assert_equal csv_query_profile(few), csv_query_profile(many)
    assert_equal few.size, many.size, <<~MSG
      Query count changed from #{few.size} to #{many.size}.
      Profile: #{csv_query_profile(many).inspect}
    MSG
    assert response.body.start_with?(few_body)
  end

  test "index filters by producer" do
    product = basket_content_products(:carrots)
    product.update!(producer: producers(:farm))
    create_basket_content(product: product)
    create_basket_content(product: basket_content_products(:cucumbers))

    get basket_contents_path(q: { producer_id_eq: producers(:farm).id })

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "td", text: product.name
  end

  test "product index filters by producer" do
    product = basket_content_products(:carrots)
    product.update!(producer: producers(:farm))

    get basket_content_products_path(q: { producer_id_eq: producers(:farm).id })

    assert_response :success
    assert_select "tbody tr#basket_content_product_#{product.id}"
    assert_select "tbody tr", count: 1
  end

  test "new form labels a product with its producer" do
    product = basket_content_products(:carrots)
    product.update!(producer: producers(:farm))

    get new_basket_content_path

    assert_response :success
    select = css_select("select[name='basket_content[product_id]']").first
    option = css_select(select, "option[value='#{product.id}']").first
    assert_equal "Farm > Carrots", option.text
    assert_nil option["data-search"]
    assert_equal I18n.t("active_admin.searchable_select.basket_content_products_placeholder"),
      select["data-searchable-select-placeholder-value"]
  end

  test "product form locks the default price" do
    product = basket_content_products(:carrots)
    product.update!(default_price: 4.25)

    get edit_basket_content_product_path(product)

    assert_response :success
    assert_select "input#basket_content_product_default_price[value='4.25']"
    assert_select "input#basket_content_product_default_price_locked[type='checkbox']"
    assert_select "#basket_content_product_default_price_locked_input.admin-formula-force"
    price = response.body.index('id="basket_content_product_default_price"')
    lock = response.body.index('id="basket_content_product_default_price_locked"')
    assert_operator price, :<, lock
    assert_select "li.input p.inline-hints",
      text: I18n.t("formtastic.hints.basket_content/product.default_price")
    assert_select "#basket_content_product_default_price_locked_input label",
      text: BasketContent::Product.human_attribute_name(:default_price_locked)
    assert_select "#basket_content_product_default_price_locked_input .inline-hints",
      text: I18n.t("formtastic.hints.basket_content/product.default_price_locked")

    patch basket_content_product_path(product), params: {
      basket_content_product: {
        default_price: "4.25",
        default_price_locked: "1",
        unit: "kg",
        name_en: "Carrots"
      }
    }

    assert_response :redirect
    product.reload
    assert product.default_price_locked?
    assert_equal BigDecimal("4.25"), product.default_price

    get edit_basket_content_product_path(product)

    assert_response :success
    assert_select "input#basket_content_product_default_price_locked[checked]"
    assert_select "li.input p.inline-hints",
      text: I18n.t("formtastic.hints.basket_content/product.default_price")

    patch basket_content_product_path(product), params: {
      basket_content_product: { default_price_locked: "0" }
    }

    assert_not product.reload.default_price_locked?
  end

  test "product index marks a locked default price" do
    product = basket_content_products(:carrots)
    product.update!(default_price: 4.25, default_price_locked: true)
    locked = BasketContent::Product.human_attribute_name(:default_price_locked)
    unlocked = BasketContent::Product.human_attribute_name(:default_price_unlocked)

    get basket_content_products_path

    assert_response :success
    assert_select "tr#basket_content_product_#{product.id} button[title='#{locked}']"
    assert_select "tr#basket_content_product_#{product.id} input[name='default_price'][value='4.25']"
    assert_select "button[title='#{locked}']", count: 1
    assert_select "button[title='#{unlocked}']"
  end

  test "product index toggles the default price lock" do
    product = basket_content_products(:carrots)
    product.update!(default_price_locked: false)

    patch toggle_default_price_lock_basket_content_product_path(product)

    assert_redirected_to basket_content_products_path
    assert product.reload.default_price_locked?

    patch toggle_default_price_lock_basket_content_product_path(product)

    assert_not product.reload.default_price_locked?
  end

  test "product index updates the default price inline" do
    product = basket_content_products(:carrots)
    product.update!(default_price: 4.25)

    patch inline_update_default_price_basket_content_product_path(product),
      params: { default_price: "3.5" }

    assert_redirected_to basket_content_products_path
    assert_equal BigDecimal("3.5"), product.reload.default_price

    patch inline_update_default_price_basket_content_product_path(product),
      params: { default_price: "" }

    assert_nil product.reload.default_price
  end

  test "product index filters locked default prices" do
    product = basket_content_products(:carrots)
    product.update!(default_price_locked: true)

    get basket_content_products_path(q: { default_price_locked_eq: true })

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody tr#basket_content_product_#{product.id}"
  end

  test "product index does not use its collection delivery association for ordering" do
    product = basket_content_products(:carrots)
    create_basket_content(product: product, delivery: deliveries(:monday_1))
    create_basket_content(product: product, delivery: deliveries(:monday_2))

    get basket_content_products_path(order: "name_asc")

    assert_response :success
    assert_select "tbody tr#basket_content_product_#{product.id}", count: 1
  end

  test "index shows producer prices for the selected delivery" do
    delivery = deliveries(:monday_1)
    farm = producers(:farm)
    garden = Producer.create!(name: "Les jardins de la colline aux longues saisons")
    carrots = basket_content_products(:carrots)
    cucumbers = basket_content_products(:cucumbers)
    carrots.update!(producer: farm)
    cucumbers.update!(producer: garden)
    baskets(:bob_1).update_column(:quantity, 2)
    baskets(:john_1).update_column(:quantity, 1)
    baskets(:anna_1).update_column(:quantity, 0)
    create_basket_content(
      product: carrots,
      delivery: delivery,
      basket_size_ids_quantities: { small_id => 500, medium_id => 1000 },
      unit: "kg",
      unit_price: 4)
    create_basket_content(
      product: cucumbers,
      delivery: delivery,
      basket_size_ids_quantities: { small_id => 2, medium_id => 1 },
      unit: "pc",
      unit_price: 3)

    get basket_contents_path(q: {
      delivery_id_eq: delivery.id,
      product_id_eq: carrots.id,
      basket_size_eq: small_id
    })

    assert_response :success
    assert_select "#producers_sidebar_section .admin-side-panel-title", text: "Producers"
    assert_select ".bc-producer-total:not(.is-total)", count: 2
    assert_select ".bc-producer-total-name", text: garden.name
    assert_select ".bc-producer-total", text: /#{Regexp.escape(garden.name)}/ do |rows|
      assert_includes rows.first.text, "15.00"
      assert_includes rows.first.text, "65%"
    end
    assert_select ".bc-producer-total", text: /Farm/ do |rows|
      assert_includes rows.first.text, "8.00"
      assert_includes rows.first.text, "35%"
    end
    assert_select ".bc-producer-total.is-total", text: /23.00/
    assert_match(/id="filters_sidebar_section".*id="producers_sidebar_section"/m, response.body)
  end

  test "index hides producer prices without a delivery, producer, or price" do
    product = basket_content_products(:carrots)
    create_basket_content(
      product: product,
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2)

    get basket_contents_path(q: { delivery_id_eq: deliveries(:monday_1).id })

    assert_response :success
    assert_select "#producers_sidebar_section", count: 0

    get basket_contents_path(q: { product_id_eq: product.id })

    assert_response :success
    assert_select "#producers_sidebar_section", count: 0
  end

  test "index hides total sidebar when delivery filter is present" do
    product = basket_content_products(:carrots)
    create_basket_content(
      product: product,
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2)

    get basket_contents_path(q: {
      product_id_eq: product.id,
      delivery_id_eq: deliveries(:monday_1).id
    })

    assert_response :success
    refute_includes response.body, BasketContent.human_attribute_name(:quantity)
  end

  test "index shows duplicate_all_to sidebar for later deliveries missing products" do
    source = deliveries(:monday_1)
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: source,
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2)

    get basket_contents_path(q: { delivery_id_eq: source.id })

    assert_response :success
    assert_select "form.sidebar_form" do
      assert_select "input[name='from_delivery_id'][value='#{source.id}']"
      assert_select "select[name='to_delivery_id'] option[value='#{deliveries(:monday_2).id}']"
    end
    assert_select "input[name='to_delivery_id']", count: 0
  end

  test "index shows duplicate_all_from sidebar when other deliveries have extra products" do
    target = deliveries(:monday_1)
    source = deliveries(:monday_2)
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: target,
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2)
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: source,
      basket_size_ids_quantities: { small_id => 1 },
      unit: "pc",
      unit_price: 1.5)

    get basket_contents_path(q: { delivery_id_eq: target.id })

    assert_response :success
    assert_select "form.sidebar_form" do
      assert_select "input[name='to_delivery_id'][value='#{target.id}']"
      assert_select "select[name='from_delivery_id'] option[value='#{source.id}']"
    end
  end

  test "index duplicate sidebars do not issue per-delivery basket content existence queries" do
    target = deliveries(:monday_1)
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: target,
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2)
    (2..8).each do |i|
      create_basket_content(
        product: basket_content_products(:cucumbers),
        delivery: deliveries(:"monday_#{i}"),
        basket_size_ids_quantities: { small_id => 1 },
        unit: "pc",
        unit_price: 1.5)
    end

    per_row = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      # The old N+1 issued EXISTS per source delivery_id. Ignore the
      # one-off with_unit_price checks used by the prices panel.
      if sql.match?(/SELECT 1 AS one FROM ["`]?basket_contents/i) && !sql.include?("unit_price")
        per_row << sql
      end
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get basket_contents_path(q: { delivery_id_eq: target.id })
    end

    assert_response :success
    assert_select "select[name='from_delivery_id'] option", minimum: 7
    assert_empty per_row
  end

  test "edit form renders basket content form frame" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      unit: "kg",
      unit_price: 2.0)

    get edit_basket_content_path(bc)

    assert_response :success
    assert_select "form[data-controller~='basket-content-form'][data-basket-content-form-target='form']"
    assert_select "turbo-frame#basket-content-form[data-basket-content-form-target='frame']"
    assert_select "input[name='basket_content[basket_size_ids_quantities][#{small_id}]']"
    assert_select "input[name='basket_content[basket_size_ids_quantities][#{medium_id}]']"
    assert_select "input#basket_content_total_quantity[name='total_quantity'][step='0.1']"
    assert_select "[data-distribution-surplus]", false
    assert_select "input[name='basket_size_ids_percentages[#{small_id}]']"
    assert_select "button[data-preset='pro_rated']"
    assert_select "button[data-preset='even']"
    assert_select "button[data-preset='pc_1_each']", false
    assert_select "button[data-preset='pc_2_each']", false
  end

  test "edit form with distribution params computes from total" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      unit: "kg",
      unit_price: 2.0)

    get edit_basket_content_path(bc), params: {
      distribution_source: "total",
      total_quantity: "3",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: basket_content_products(:carrots).id,
        unit_price: "2",
        depot_ids: [ "", depots(:home).id, depots(:farm).id ],
        basket_size_ids_quantities: {
          small_id => 0,
          medium_id => 0
        }
      },
      basket_size_ids_percentages: {
        small_id => 33,
        medium_id => 67
      }
    }

    assert_response :success
    assert_select "turbo-frame#basket-content-form"
    # Should compute quantities from percentages (non-zero values)
    assert_select "input[name='basket_content[basket_size_ids_quantities][#{small_id}]'][value='0']", false
  end

  test "edit form with distribution params does not persist depot selection" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      unit: "kg",
      unit_price: 2.0)
    original_depot_ids = bc.depot_ids.sort

    get edit_basket_content_path(bc), params: {
      distribution_source: "quantity",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: basket_content_products(:carrots).id,
        unit_price: "2",
        depot_ids: [ "", depots(:home).id ],
        basket_size_ids_quantities: {
          small_id => 500,
          medium_id => 750
        }
      },
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      }
    }

    assert_response :success
    assert_equal original_depot_ids, bc.reload.depot_ids.sort
    assert_select "input[type='checkbox'][name='basket_content[depot_ids][]'][value='#{depots(:home).id}'][checked]"
    assert_select "input[type='checkbox'][name='basket_content[depot_ids][]'][value='#{depots(:farm).id}'][checked]", false
  end

  test "update saves submitted quantities directly" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 100, medium_id => 100 },
      unit: "kg",
      unit_price: 2.0)

    patch basket_content_path(bc), params: {
      distribution_source: "quantity",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: basket_content_products(:carrots).id,
        unit_price: "3.5",
        depot_ids: [ "", depots(:home).id, depots(:farm).id ],
        basket_size_ids_quantities: {
          small_id => 400,
          medium_id => 600
        }
      }
    }

    assert_redirected_to basket_contents_path(q: { delivery_id_eq: deliveries(:monday_1).id })
    bc.reload
    assert_equal 400, bc.basket_size_ids_quantity(small_id)
    assert_equal 600, bc.basket_size_ids_quantity(medium_id)
    assert_equal 3.5, bc.unit_price
  end

  test "update with product change saves submitted values as-is" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2.0)
    new_product = basket_content_products(:cucumbers)

    # When changing product, the Turbo frame reloads and shows correct
    # quantities in the new product's unit. The submit button is disabled
    # until the frame finishes reloading, so submitted values are always
    # consistent with the selected product.
    patch basket_content_path(bc), params: {
      distribution_source: "quantity",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: new_product.id,
        unit_price: "4.25",
        depot_ids: [ "", depots(:home).id ],
        basket_size_ids_quantities: { small_id => 5, medium_id => 7 }
      }
    }

    assert_redirected_to basket_contents_path(q: { delivery_id_eq: deliveries(:monday_1).id })
    bc.reload
    assert_equal new_product, bc.product
    assert_equal "pc", bc.unit
    assert_equal 4.25, bc.unit_price
    assert_equal 5, bc.basket_size_ids_quantity(small_id)
    assert_equal 7, bc.basket_size_ids_quantity(medium_id)
  end

  test "edit form with distribution params computes from quantities" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      unit: "kg",
      unit_price: 2.0)

    get edit_basket_content_path(bc), params: {
      distribution_source: "quantity",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: basket_content_products(:carrots).id,
        unit_price: "2",
        depot_ids: [ "", depots(:home).id, depots(:farm).id ],
        basket_size_ids_quantities: {
          small_id => 500,
          medium_id => 750
        }
      },
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      }
    }

    assert_response :success
    assert_select "turbo-frame#basket-content-form"
    assert_select "input#basket_content_total_quantity[value='1.3']"
  end

  test "new form renders basket content form frame" do
    get new_basket_content_path

    assert_response :success
    assert_select "turbo-frame#basket-content-form"
  end

  test "new form searches products and pins recently distributed ones" do
    product = basket_content_products(:carrots)
    create_basket_content(product: product, delivery: deliveries(:monday_1))

    get new_basket_content_path

    assert_response :success
    select = css_select("select[name='basket_content[product_id]']").first
    assert_equal "searchable-select", select["data-controller"]
    assert_equal "change->basket-content-form#changed form-hint-url#change", select["data-action"]
    assert_select select, "optgroup[label=?] option[value='#{product.id}'][data-recent='true']",
      I18n.t("active_admin.searchable_select.recent")
    assert_select select, "optgroup[label=?] option[value='#{product.id}']",
      I18n.t("active_admin.searchable_select.all"), count: 0
  end

  test "edit form frame applies product defaults when product changes" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2.0)
    product = basket_content_products(:cucumbers)
    product.update!(default_price: 4.25, default_basket_quantities: { small_id.to_s => 5 })

    get edit_basket_content_path(bc), params: {
      distribution_source: "product",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: product.id,
        unit_price: "999",
        depot_ids: [ "", depots(:home).id ],
        basket_size_ids_quantities: { small_id => 999 }
      },
      basket_size_ids_percentages: { small_id => 100 }
    }

    assert_response :success
    assert_select "turbo-frame#basket-content-form"
    assert_select "select#basket_content_product_id option[value='#{product.id}'][selected]"
    assert_select "input#basket_content_unit_price[value='4.25']"
    assert_select "input#basket_content_total_quantity[step='1']"
    assert_select "input[name='basket_content[basket_size_ids_quantities][#{small_id}]'][value='5']"
    assert_select ".bc-price-unit-suffix", text: "/piece"
  end

  test "edit form with empty depot selection shows zero counts" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2.0)

    get edit_basket_content_path(bc), params: {
      distribution_source: "quantity",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        depot_ids: [ "" ],
        basket_size_ids_quantities: { small_id => 500 }
      },
      basket_size_ids_percentages: { small_id => 100 }
    }

    assert_response :success
    assert_select "li[data-baskets-count='0']", minimum: 1
  end

  test "edit form renders depot checkboxes" do
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2.0)

    get edit_basket_content_path(bc), params: {
      distribution_source: "quantity",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        depot_ids: [ "", depots(:home).id ],
        basket_size_ids_quantities: { small_id => 500 }
      },
      basket_size_ids_percentages: { small_id => 100 }
    }

    assert_response :success
    assert_select "input[type='checkbox'][name='basket_content[depot_ids][]']", minimum: 1
    assert_select "input[type='checkbox'][name='basket_content[depot_ids][]'][value='#{depots(:home).id}'][checked]"
  end

  test "edit form renders price information for zero quantity basket sizes" do
    BasketContent.create!(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:cucumbers),
      depots: [ depots(:home), depots(:farm) ],
      unit: "pc",
      unit_price: 1.5,
      basket_size_ids_quantities: { small_id => 2 })
    bc = create_basket_content(
      basket_size_ids_quantities: { medium_id => 500 },
      unit: "kg",
      unit_price: 2.0)

    get edit_basket_content_path(bc), params: {
      distribution_source: "quantity",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: basket_content_products(:carrots).id,
        unit_price: "2",
        depot_ids: [ "", depots(:home).id, depots(:farm).id ],
        basket_size_ids_quantities: {
          small_id => 0,
          medium_id => 500
        }
      },
      basket_size_ids_percentages: {
        small_id => 0,
        medium_id => 100
      }
    }

    assert_response :success
    assert_select "li[data-basket-size-id='#{small_id}']" do
      assert_select "[data-basket-size-price-info]", minimum: 1
    end
  end

  test "edit form with pc total params does not bump requested total" do
    product = basket_content_products(:cucumbers)
    bc = BasketContent.create!(
      delivery: deliveries(:monday_1),
      product: product,
      depots: Depot.kept,
      unit: "pc",
      unit_price: 1.5,
      basket_size_ids_quantities: {
        small_id => 1,
        medium_id => 1,
        large_id => 1
      })

    get edit_basket_content_path(bc), params: {
      distribution_source: "total",
      total_quantity: "2",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: product.id,
        unit_price: "1.5",
        depot_ids: [ "", *Depot.kept.pluck(:id) ],
        basket_size_ids_quantities: {
          small_id => 0,
          medium_id => 0,
          large_id => 0
        }
      },
      basket_size_ids_percentages: {
        small_id => 0,
        medium_id => 0,
        large_id => 0
      }
    }

    assert_response :success
    assert_select "input[name^='basket_size_ids_target_percentages']", minimum: 1
    assert_select "input#basket_content_total_quantity[value='2']"
    assert_select "input[value='1'][name^='basket_content[basket_size_ids_quantities]']", count: 2
    assert_select "input[value='0'][name^='basket_content[basket_size_ids_quantities]']", count: 1
    assert_select "button[data-preset='pc_1_each']", text: I18n.t("basket_content.preset.pc_1_each")
    assert_select "button[data-preset='pc_2_each']", text: I18n.t("basket_content.preset.pc_2_each")
    assert_select "button[data-preset='pro_rated']", false
    assert_select "button[data-preset='even']", false
  end

  test "edit form with pc preset renders actual percentages and hidden target percentages" do
    baskets(:bob_1).update_column(:quantity, 48)
    baskets(:john_1).update_column(:quantity, 92)
    baskets(:anna_1).update_column(:quantity, 12)

    product = basket_content_products(:cucumbers)
    bc = BasketContent.create!(
      delivery: deliveries(:monday_1),
      product: product,
      depots: Depot.kept,
      unit: "pc",
      unit_price: 1.5,
      basket_size_ids_quantities: {
        small_id => 3,
        medium_id => 0,
        large_id => 2
      })

    get edit_basket_content_path(bc), params: {
      distribution_source: "total",
      preset: "even",
      total_quantity: "104",
      basket_content: {
        delivery_id: deliveries(:monday_1).id,
        product_id: product.id,
        unit_price: "1.5",
        depot_ids: [ "", *Depot.kept.pluck(:id) ],
        basket_size_ids_quantities: {
          small_id => 3,
          medium_id => 0,
          large_id => 2
        }
      },
      basket_size_ids_percentages: {
        small_id => 60,
        medium_id => 0,
        large_id => 40
      }
    }

    assert_response :success
    assert_select "input#basket_content_total_quantity[value='104']"
    assert_select "input[type='range'][name='basket_size_ids_percentages[#{small_id}]'][value='0']"
    assert_select "input[type='range'][name='basket_size_ids_percentages[#{medium_id}]'][value='50']"
    assert_select "input[type='range'][name='basket_size_ids_percentages[#{large_id}]'][value='50']"
    assert_select "input[type='hidden'][name='basket_size_ids_target_percentages[#{small_id}]'][value='33']"
    assert_select "input[type='hidden'][name='basket_size_ids_target_percentages[#{medium_id}]'][value='33']"
    assert_select "input[type='hidden'][name='basket_size_ids_target_percentages[#{large_id}]'][value='34']"
    assert_select "input[name='basket_content[basket_size_ids_quantities][#{small_id}]'][value='0']"
    assert_select "input[name='basket_content[basket_size_ids_quantities][#{medium_id}]'][value='1']"
    assert_select "input[name='basket_content[basket_size_ids_quantities][#{large_id}]'][value='1']"
    assert_select "button[data-preset='pc_1_each']"
    assert_select "button[data-preset='pc_2_each']"
    assert_select "button[data-preset='pro_rated']", false
    assert_select "button[data-preset='even']", false
  end

  private

  def small_id = basket_sizes(:small).id
  def medium_id = basket_sizes(:medium).id
  def large_id = basket_sizes(:large).id

  def delivery_dates
    css_select('tbody td[data-column="delivery"]').map { |cell| cell.text.strip }
  end

  def create_basket_content(**attrs)
    BasketContent.create!(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:carrots),
      depots: [ depots(:home), depots(:farm) ],
      **attrs)
  end

  def seed_csv_basket_contents!
    create_basket_content(
      depots: Depot.kept.to_a,
      basket_size_ids_quantities: { small_id => 500, medium_id => 250 },
      unit_price: 2)
    create_basket_content(
      product: basket_content_products(:cucumbers),
      depots: [ depots(:farm), depots(:bakery) ],
      basket_size_ids_quantities: { small_id => 1, medium_id => 2 },
      unit_price: 3)
    create_basket_content(
      delivery: deliveries(:monday_2),
      depots: [ depots(:home) ],
      basket_size_ids_quantities: { medium_id => 1000 },
      unit_price: 4)
  end

  def collect_sql_queries
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      queries << sql unless payload[:name] == "SCHEMA" || sql.match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def csv_query_profile(queries)
    {
      basket_sums: queries.count { |sql|
        sql.match?(/\bSUM\(/i) && sql.match?(/FROM ["`]baskets["`]/i)
      },
      depot_counts: queries.count { |sql|
        sql.match?(/\bCOUNT\(\*\)/i) && sql.match?(/["`]depots["`]/i)
      },
      depot_groups: queries.count { |sql|
        sql.match?(/FROM ["`]depot_groups["`]/i)
      },
      depot_loads: queries.count { |sql|
        sql.match?(/FROM ["`]depots["`]/i) && !sql.match?(/\bCOUNT\(\*\)/i)
      },
      eager_joins: queries.count { |sql|
        sql.match?(/FROM ["`]basket_contents["`]/i) && sql.match?(/LEFT OUTER JOIN/i)
      },
      depot_link_preloads: queries.count { |sql|
        sql.match?(/FROM ["`]basket_contents_depots["`]/i)
      }
    }
  end

  def assert_csv_export_queries_bounded(queries)
    profile = csv_query_profile(queries)
    assert_operator profile[:basket_sums], :<=, 1, profile.inspect
    assert_operator profile[:depot_counts], :<=, 1, profile.inspect
    assert_operator profile[:depot_groups], :<=, 1, profile.inspect
    assert_operator profile[:depot_loads], :<=, 6, profile.inspect
    assert_equal 0, profile[:eager_joins], profile.inspect
    assert_equal 1, profile[:depot_link_preloads], profile.inspect
  end

  def money(amount)
    ApplicationController.helpers.cur(amount)
  end

  def basket_content_csv_row(basket_content, counts:, quantities:, prices:, depots:)
    delivery = basket_content.delivery
    [
      delivery.date.to_s,
      I18n.t("date.month_names")[delivery.date.month],
      I18n.t("date.day_names")[delivery.date.wday],
      basket_content.product.name,
      basket_content.product.producer&.name,
      I18n.t("units.#{basket_content.unit}.flex"),
      money(basket_content.unit_price),
      basket_content.quantity.to_s,
      *BasketSize.paid.ordered.flat_map { |size|
        [
          counts.fetch(size.name),
          quantities.fetch(size.name),
          prices.fetch(size.name)
        ]
      },
      depots
    ]
  end

  def expected_basket_contents_csv(rows)
    headers = [
      BasketContent.human_attribute_name(:date),
      BasketContent.human_attribute_name(:month),
      BasketContent.human_attribute_name(:wday),
      BasketContent.human_attribute_name(:product),
      BasketContent.human_attribute_name(:producer),
      BasketContent.human_attribute_name(:unit),
      BasketContent.human_attribute_name(:unit_price),
      BasketContent.human_attribute_name(:quantity)
    ]
    BasketSize.paid.ordered.each do |size|
      headers << "#{size.name} - #{Basket.model_name.human(count: 2)}".humanize
      headers << "#{size.name} - #{I18n.t("attributes.quantity")}".humanize
      headers << "#{size.name} - #{BasketContent.human_attribute_name(:price)}".humanize
    end
    headers << BasketContent.human_attribute_name(:depots)

    csv = String.new("\xEF\xBB\xBF", encoding: Encoding::UTF_8)
    csv << CSV.generate_line(headers)
    rows.each { |row| csv << CSV.generate_line(row) }
    csv
  end
end

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
      assert_select ".font-bold", minimum: 1
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

  def create_basket_content(**attrs)
    BasketContent.create!(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:carrots),
      depots: [ depots(:home), depots(:farm) ],
      **attrs)
  end
end

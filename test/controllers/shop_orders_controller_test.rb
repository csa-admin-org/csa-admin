# frozen_string_literal: true

require "test_helper"

class ShopOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-01-01"
    host! "admin.acme.test"
    login admins(:super)
  end

  test "new form searches members and pins recent shop members" do
    get new_shop_order_path

    assert_response :success
    select = css_select("select[name='shop_order[member_id]']").first
    assert_equal "searchable-select", select["data-controller"]
    assert_select select, "option[value='']"
    assert_select select, "optgroup[label=?]", I18n.t("active_admin.searchable_select.recent") do
      assert_select "option[value='#{members(:john).id}'][data-recent='true']"
    end
    assert_select select, "optgroup[label=?] option[value='#{members(:john).id}']",
      I18n.t("active_admin.searchable_select.all"), count: 0
    values = select.css("option[value]:not([value=''])").map { |option| option["value"] }
    assert_equal values.uniq, values
  end

  test "new form searches variants in the added item template" do
    get new_shop_order_path

    assert_response :success
    html = css_select("a.has-many-add").first["data-html"]
    assert_includes html, "product_variant_id"
    assert_includes html, "searchable-select"
    assert_includes html, "form-reset#reset"
    assert_includes html, I18n.t("active_admin.searchable_select.products_placeholder")
    assert_not_includes html, "[product_id]"
    assert_select "select[name*='[product_id]']", count: 0
  end

  test "edit form searches variants by product producer and tag" do
    order = shop_orders(:john)
    variant = shop_product_variants(:bread_500)
    shop_products(:bread).tags << Shop::Tag.create!(names: { "en" => "Bakery" }, emoji: "🍞")

    get edit_shop_order_path(order)

    assert_response :success
    select = css_select("select[name='shop_order[items_attributes][0][product_variant_id]']").first
    assert_select "label[for='#{select["id"]}']",
      text: I18n.t("active_admin.searchable_select.product_and_variant")
    assert_equal "searchable-select", select["data-controller"]
    assert_equal I18n.t("active_admin.searchable_select.products_placeholder"),
      select["data-searchable-select-placeholder-value"]
    option = css_select(select, "option[value='#{variant.id}']").first
    assert_equal "Bread > 500g", option.text
    assert_includes option["data-search"], "Farm"
    assert_includes option["data-search"], "Bakery"
    assert_equal "5", option["data-price"]
    assert_select "select[name*='[product_id]']", count: 0
    assert_select select, "optgroup[label=?] option[value='#{variant.id}'][data-recent='true']",
      I18n.t("active_admin.searchable_select.recent")
    assert_select select, "optgroup[label=?] option[value='#{variant.id}']",
      I18n.t("active_admin.searchable_select.all"), count: 0
  end

  test "edit blanks item price that matches the variant default" do
    order = shop_orders(:john)
    item = shop_order_items(:john_bread_500)

    get edit_shop_order_path(order)

    assert_response :success
    price = css_select("input[name='shop_order[items_attributes][0][item_price]']").first
    assert price
    assert_equal "", price["value"].to_s
    assert_equal "5", price["placeholder"]
    assert_select "select[name='shop_order[items_attributes][0][product_variant_id]'] option[value='#{item.product_variant_id}'][data-price='5']"
  end

  test "edit keeps an item price override" do
    item = shop_order_items(:john_bread_500)
    item.update_column(:item_price, 6.5)

    get edit_shop_order_path(item.order)

    assert_response :success
    price = css_select("input[name='shop_order[items_attributes][0][item_price]']").first
    assert_equal "6.5", price["value"]
    assert_equal "5", price["placeholder"]
  end

  test "index disables delivery PDF until a delivery is filtered" do
    travel_to "2024-01-01"
    login admins(:super)

    get shop_orders_path

    assert_response :success
    assert_select "select[name='q[member_id_eq]'][data-controller='searchable-select']"
    assert_select "select[name='q[member_id_eq]'] optgroup", count: 0
    assert_select "a[href*='#{delivery_shop_orders_path(format: :pdf)}']", false
    assert_select ".action-item-button.is-disabled"
    assert_select ".tooltip-body",
      text: I18n.t("active_admin.shared.action_items.delivery_orders_filter_required")
  end

  test "index enables delivery PDF when filtered by delivery" do
    travel_to "2024-01-01"
    login admins(:super)
    delivery = deliveries(:monday_1)

    get shop_orders_path, params: { q: { _delivery_gid_eq: delivery.gid } }

    assert_response :success
    plain = "#{I18n.l(delivery.date, format: :medium)} ##{delivery.number}"
    title = css_select("title").text
    assert_includes title, plain
    assert_not_includes title, "<"
    assert_select "h2.admin-page-title", text: /#{Regexp.escape(plain)}/
    assert_not_includes css_select("h2.admin-page-title").text, "<"
    assert_select "a.action-item-button[href*='.pdf']",
      text: I18n.t("active_admin.shared.action_items.delivery_orders")
    assert_select ".action-item-button.is-disabled",
      text: I18n.t("active_admin.shared.action_items.delivery_orders"), count: 0
  end

  test "pending period order shows a star and no single invoice action" do
    travel_to "2024-04-10"
    members(:jane).update!(shop_invoice_period: "month")
    order = create_shop_order(member: members(:jane), delivery: deliveries(:monday_1))
    sibling = create_shop_order(member: members(:jane), delivery: deliveries(:thursday_1))
    deliveries(:monday_2).update!(date: Date.new(2024, 4, 20))
    future = create_shop_order(member: members(:jane), delivery: deliveries(:monday_2))

    get shop_orders_path, params: { scope: :pending }

    assert_response :success
    assert_select "#tooltip-shop-order-#{order.id}-period .tooltip-body",
      text: I18n.t("shop.group_invoice.waiting_tooltip",
        date: I18n.l(order.group_billing_on, format: :long))
    assert_select ".tooltip-wrap:has(#tooltip-shop-order-#{order.id}-period) .tooltip-trigger[role=button] .status-tag[data-status=pending]",
      text: "#{I18n.t("shop.group_invoice.to_invoice")}*"
    assert_select ".tooltip-wrap:has(#tooltip-shop-order-#{future.id}-period) .tooltip-trigger[role=button] .status-tag[data-status=pending]",
      text: "#{future.state_i18n_name}*"
    assert order.pending?
    assert future.pending?

    get shop_order_path(order)

    assert_response :success
    assert_select ".admin-info-pane", text: /##{sibling.id}/
    assert_select ".admin-info-pane", text: I18n.t("shop.group_invoice.no_other_orders"), count: 0
    assert_select "form[action='#{invoice_period_shop_order_path(order)}'] button[data-confirm=?]",
      I18n.t("shop.group_invoice.future_confirm")
    assert_select "form[action='#{invoice_shop_order_path(order)}']", count: 0
    assert_select "a[href='#{invoice_shop_order_path(order)}']", count: 0
    assert future.delivery_date.future?
  end

  test "invoice now bills every pending order in the period" do
    travel_to "2024-04-10"
    members(:jane).update!(shop_invoice_period: "month")
    order = create_shop_order(member: members(:jane), delivery: deliveries(:monday_1))
    sibling = create_shop_order(member: members(:jane), delivery: deliveries(:thursday_1))

    assert_difference -> { Invoice.count }, 1 do
      post invoice_period_shop_order_path(order)
    end

    assert_redirected_to invoice_path(order.reload.invoice)
    assert_equal order.invoice, sibling.reload.invoice
    assert_equal "Shop::OrderGroup", order.invoice.entity_type
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end

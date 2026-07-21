# frozen_string_literal: true

require "test_helper"

class AdminTableRowNavigationTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-01-01"
    host! "admin.acme.test"
    login admins(:super)
  end

  test "absence table rows target memberships and mail deliveries" do
    absence = absences(:jane_thursday_5)
    mail_delivery = MailDelivery.create!(
      mailable_type: "Absence",
      mailable_ids: [ absence.id ],
      action: "created",
      member: absence.member,
      state: :not_delivered,
      subject: "Absence confirmation")

    get absence_path(absence)

    assert_response :success
    assert_show_row_link membership_path(absence.baskets.first.membership)
    assert_show_row_link mail_delivery_path(mail_delivery)
  end

  test "delivery cycle rows target deliveries and depots" do
    delivery_cycle = delivery_cycles(:mondays)

    get delivery_cycle_path(delivery_cycle)

    assert_response :success
    assert_show_row_link delivery_path(delivery_cycle.current_deliveries.first)
    assert_show_row_link depot_path(delivery_cycle.depots.first)
  end

  test "depot rows target memberships and delivery cycles outside sortable mode" do
    depot = depots(:farm)
    delivery = deliveries(:monday_1)
    membership = depot.baskets_for(delivery).first.membership

    get depot_path(depot, delivery_id: delivery.id)

    assert_response :success
    assert_show_row_link membership_path(membership)
    assert_show_row_link delivery_cycle_path(depot.delivery_cycles.first)
  end

  test "sortable depot rows remain excluded from table row navigation" do
    get depot_path(depots(:home), delivery_id: deliveries(:monday_1).id)

    assert_response :success
    assert_select "tbody[data-controller='sortable']"
    assert_select "tbody[data-controller='sortable'] tr[data-table-row-target='row']", count: 0
  end

  test "invoice payment rows target payments" do
    invoice = invoices(:other_closed)

    get invoice_path(invoice)

    assert_response :success
    assert_show_row_link payment_path(invoice.payments.first)
  end

  test "mail template rows target delivery cycles" do
    delivery_cycle = delivery_cycles(:mondays)
    template = mail_templates(:basket_initial)
    template.update!(active: true, delivery_cycle_ids: [ delivery_cycle.id ])

    get mail_template_path(template)

    assert_response :success
    assert_show_row_link delivery_cycle_path(delivery_cycle)
  end

  test "shop order item rows target products" do
    order = shop_orders(:john)

    get shop_order_path(order)

    assert_response :success
    assert_row_link edit_shop_product_path(order.items.first.product), action: "edit"
  end

  test "special delivery total rows target products" do
    delivery = shop_special_deliveries(:wednesday)
    product = shop_products(:bread)
    delivery.products << product
    create_shop_order(
      delivery: delivery,
      items_attributes: {
        "0" => {
          product_id: product.id,
          product_variant_id: shop_product_variants(:bread_500).id,
          quantity: 1
        }
      })

    get shop_special_delivery_path(delivery)

    assert_response :success
    assert_row_link edit_shop_product_path(product), action: "edit"
  end

  private

  def assert_show_row_link(path)
    assert_row_link path, action: "show"
  end

  def assert_row_link(path, action:)
    links = css_select(
      "tr[data-table-row-target='row'] a[data-table-row-action='#{action}']")
    assert links.any? { |link| link["href"] == path },
      "Expected row link to #{path.inspect}; found #{links.map { |link| link["href"] }.inspect}"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end

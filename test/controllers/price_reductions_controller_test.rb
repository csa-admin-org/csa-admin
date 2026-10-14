# frozen_string_literal: true

require "test_helper"

class PriceReductionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "new form groups the cut, the registration fields, and handbook hints" do
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)

    get new_price_reduction_path

    assert_response :success
    assert_select "input#price_reduction_public_name_en"
    assert_select "input#price_reduction_admin_name_en"
    assert_select "fieldset", text: /Reduction/ do
      assert_select "[data-controller='form-exclusive']" do
        assert_select "input#price_reduction_percentage[data-form-exclusive-target='input']"
        assert_select "input#price_reduction_fixed_amount[data-form-exclusive-target='input']"
        assert_select ".single-line-separator", text: "or"
        assert_select "a[href=?]", handbook_page_path("price_reductions", anchor: "programs")
      end
      assert_select ".inline-hints", text: /One or the other\. Only the membership price is reduced/
      assert_select "a[href=?]", handbook_page_path("price_reductions", anchor: "renewal")
      assert_select "a[href=?]", handbook_page_path("price_reductions", anchor: "cards")
      assert_select "input#price_reduction_renew"
      assert_select "label", text: "Required card"
      assert_select "select#price_reduction_price_reduction_card_id"
    end
    assert_select "fieldset", text: /Cap/ do
      assert_select "a[href=?]", handbook_page_path("price_reductions", anchor: "cap")
      assert_select "ol > li.panel-actions a[href=?]", handbook_page_path("price_reductions", anchor: "cap")
    end
    assert_select "fieldset[data-controller='form-details-preview']" do
      assert_select "select#price_reduction_visible"
      assert_select "select#price_reduction_member_order_priority"
      assert_select "input#price_reduction_form_detail_en[data-form-details-preview-target='input']"
      assert_select "turbo-frame#price-reduction-form-details"
    end
    assert_select "fieldset", text: /Availability/ do
      assert_select "select#price_reduction_price_reduction_card_id", count: 0
    end
    assert_select "fieldset", text: /Invoice/ do
      assert_select "label", text: "Labels/Certifications"
      assert_select "input#price_reduction_invoice_logo[type=file]"
      assert_select ".inline-hints", text: /membership invoices that benefit from this reduction/
      assert_select ".settings-invoice-row", count: 0
    end
  end

  test "form details preview follows the percentage and the card" do
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)
    card = PriceReductionCard.create!(names: { "en" => "Culture card" }, require_number: true)

    get form_details_preview_price_reductions_path, params: {
      price_reduction: {
        percentage: "12.5",
        price_reduction_card_id: card.id
      }
    }

    assert_response :success
    assert_select "turbo-frame#price-reduction-form-details [data-placeholder-en=?]", '12.5%, Card "Culture card" required'
  end

  test "form details preview mentions a depot restriction" do
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)

    get form_details_preview_price_reductions_path, params: {
      price_reduction: {
        percentage: "20",
        depot_ids: [ depots(:farm).id ]
      }
    }

    assert_response :success
    assert_select "turbo-frame#price-reduction-form-details [data-placeholder-en=?]", "20%, specific depots only"
  end

  test "edit form shows the uploaded invoice logo with a remove control" do
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)
    reduction = PriceReduction.create!(names: { "en" => "Caritas" }, percentage: 10)
    reduction.invoice_logo.attach(
      io: file_fixture("logo.png").open,
      filename: "bio.png",
      content_type: "image/png")

    get edit_price_reduction_path(reduction)

    assert_response :success
    assert_select "fieldset", text: /Invoice/ do
      assert_select "input[type=hidden][name='price_reduction[remove_invoice_logo]'][value=0]"
      assert_select "input[name='price_reduction[invoice_logo]'][type=hidden]", count: 0
      assert_select "ul.settings-invoice-row li.settings-logo-item" do
        assert_select ".logo-remove[onclick*='remove_invoice_logo']"
        assert_select "img.logo-preview"
      end
    end
  end

  test "update removes the invoice logo and a new file replaces it" do
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)
    reduction = PriceReduction.create!(names: { "en" => "Caritas" }, percentage: 10)
    reduction.invoice_logo.attach(
      io: file_fixture("logo.png").open,
      filename: "bio.png",
      content_type: "image/png")

    patch price_reduction_path(reduction), params: {
      price_reduction: { remove_invoice_logo: "1" }
    }

    assert_redirected_to price_reduction_path(reduction)
    assert_not reduction.reload.invoice_logo.attached?

    patch price_reduction_path(reduction), params: {
      price_reduction: {
        invoice_logo: Rack::Test::UploadedFile.new(file_fixture("logo.png"), "image/png"),
        remove_invoice_logo: "0"
      }
    }

    assert reduction.reload.invoice_logo.attached?
  end

  test "show aligns the invoice logo to the right" do
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)
    reduction = PriceReduction.create!(names: { "en" => "Caritas" }, percentage: 10)
    reduction.invoice_logo.attach(
      io: file_fixture("logo.png").open,
      filename: "bio.png",
      content_type: "image/png")

    get price_reduction_path(reduction)

    assert_response :success
    assert_select ".admin-column:last-child tr[data-row=invoice_logo] .settings-logos img.settings-invoice-logo"
  end

  test "show puts the year stats on the left and the catalog on the right" do
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)
    reduction = PriceReduction.create!(names: { "en" => "Caritas" }, percentage: 10, cap_amount: 100)

    get price_reduction_path(reduction)

    assert_response :success
    assert_select ".admin-columns > .admin-column", count: 2
    assert_select ".admin-column:first-child .tabs-nav a[aria-selected=true]", text: Current.fiscal_year.to_s
    assert_select ".admin-column:first-child .pair-grid"
    assert_select ".admin-column:first-child table", count: 0
    assert_select ".admin-column:last-child", text: /Reduction/
    assert_select ".admin-column:last-child th", text: "Percentage"
    assert_select ".admin-column:last-child th", text: "Rule", count: 0
    assert_select ".admin-column:last-child", text: /Cap/
    assert_select ".admin-column:last-child", text: /Availability/
    assert_select ".admin-column:last-child", text: /Invoice/ do
      assert_select "th", text: "Labels/Certifications"
      assert_select ".attributes-table-empty-value", text: "Empty"
      assert_select "img.settings-invoice-logo", count: 0
    end
    assert_select ".year-tabs"
  end

  test "show includes the next fiscal year when it is already open" do
    travel_to "2026-09-26"
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)
    Delivery.order(:date).last.update_column(:date, Date.new(2027, 6, 1))
    reduction = PriceReduction.create!(names: { "en" => "Caritas" }, percentage: 10)

    get price_reduction_path(reduction)

    assert_response :success
    assert_select ".year-tabs a", text: Current.org.fiscal_year_for(2027).to_s
  end

  test "show lists the year's grants under the counters" do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
    login admins(:super)
    membership = memberships(:jane)
    reduction = PriceReduction.create!(names: { "en" => "Caritas" }, percentage: 10, cap_amount: 1000)
    MembershipPriceReduction.create!(
      membership: membership,
      price_reduction: reduction,
      percentage: 10,
      amount: 12.5)

    get price_reduction_path(reduction, year: membership.fy_year)

    assert_response :success
    assert_select ".is-year-stats table" do
      assert_select "a[href=?]", member_path(membership.member)
      assert_select "a[href=?]", membership_path(membership), text: membership.id.to_s
      assert_select "td", text: /12.50/
    end
  end
end

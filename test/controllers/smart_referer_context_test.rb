# frozen_string_literal: true

require "test_helper"

class SmartRefererContextTest < ActionDispatch::IntegrationTest
  setup do
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

  test "dashboard renders with smart referer callback" do
    get root_path

    assert_response :success
  end

  test "member show preselects member in new membership form without waiting defaults" do
    travel_to "2024-05-01 12:00" do
      member = members(:aria)

      get member_path(member)
      assert_response :success

      get new_membership_path
      assert_response :success
      assert_select "select[name='membership[member_id]'] option[value='#{member.id}'][selected]"
      assert_select "select[name='membership[depot_id]'] option[value='#{member.waiting_depot_id}'][selected]", false
    end
  end

  test "invoice show preselects invoice and member in new payment form" do
    travel_to "2024-05-01 12:00" do
      invoice = invoices(:other_closed)

      get invoice_path(invoice)
      assert_response :success

      get new_payment_path
      assert_response :success
      assert_select "fieldset[data-controller='payment-form']"
      assert_select "input[name='payment[invoice_id]'][value='#{invoice.id}'][data-payment-form-target='invoiceInput']"
      assert_select "select[name='payment[member_id]'][data-payment-form-target='member']:not([disabled]) option[value='#{invoice.member_id}'][selected]"
      assert_select "li[data-payment-form-target='invoice'] select[name='payment[invoice_id]'][disabled]"
    end
  end

  test "referer invoice filter wins over stale smart member context" do
    travel_to "2024-05-01 12:00" do
      member = members(:jane)
      invoice = invoices(:other_closed)

      get member_path(member)
      assert_response :success

      get new_payment_path, headers: {
        "HTTP_REFERER" => payments_url(q: { invoice_id_eq: invoice.id }, scope: :all)
      }
      assert_response :success
      assert_select "input[name='payment[invoice_id]'][value='#{invoice.id}']"
      assert_select "select[name='payment[member_id]'] option[value='#{invoice.member_id}'][selected]"
    end
  end

  test "explicit member param clears stale smart invoice context" do
    travel_to "2024-05-01 12:00" do
      invoice = invoices(:other_closed)
      member = members(:jane)

      get invoice_path(invoice)
      assert_response :success

      get new_payment_path(member_id: member.id)
      assert_response :success
      assert_select "select[name='payment[member_id]'] option[value='#{member.id}'][selected]"
      assert_select "input[name='payment[invoice_id]']", false
    end
  end

  test "explicit invoice param locks invoice and member in new payment form" do
    travel_to "2024-05-01 12:00" do
      invoice = invoices(:other_closed)

      get new_payment_path(invoice_id: invoice.id)
      assert_response :success
      assert_select "fieldset[data-controller='payment-form']", false
      assert_select "input[name='payment[invoice_id]'][value='#{invoice.id}']"
      assert_select "input[name='payment[member_id]'][value='#{invoice.member_id}']"
      assert_select "select[name='payment[member_id]'][disabled]"
    end
  end

  test "membership show clears stale invoice context" do
    travel_to "2024-05-01 12:00" do
      invoice = invoices(:other_closed)
      membership = memberships(:jane)

      get invoice_path(invoice)
      assert_response :success
      get membership_path(membership)
      assert_response :success

      get new_payment_path
      assert_response :success
      assert_select "select[name='payment[member_id]'] option[value='#{membership.member_id}'][selected]"
      assert_select "input[name='payment[invoice_id]']", false
    end
  end

  test "member show clears stale invoice context" do
    travel_to "2024-05-01 12:00" do
      invoice = invoices(:other_closed)
      member = members(:jane)

      get invoice_path(invoice)
      assert_response :success
      get member_path(member)
      assert_response :success

      get new_payment_path
      assert_response :success
      assert_select "select[name='payment[member_id]'] option[value='#{member.id}'][selected]"
      assert_select "input[name='payment[invoice_id]']", false
    end
  end

  test "delivery show preselects delivery in new basket content form" do
    travel_to "2024-04-01 12:00" do
      delivery = deliveries(:thursday_2)

      get delivery_path(delivery)
      assert_response :success

      get new_basket_content_path
      assert_response :success
      assert_select "select[name='basket_content[delivery_id]'] option[value='#{delivery.id}'][selected]"
    end
  end

  test "referer filter wins over smart context cookie" do
    travel_to "2024-05-01 12:00" do
      get member_path(members(:john))
      assert_response :success

      get new_membership_path, headers: {
        "HTTP_REFERER" => memberships_url(q: { member_id_eq: members(:jane).id }, scope: :all)
      }
      assert_response :success
      assert_select "select[name='membership[member_id]'] option[value='#{members(:jane).id}'][selected]"
      assert_select "select[name='membership[member_id]'] option[value='#{members(:john).id}'][selected]", false
    end
  end

  test "smart context expires after 3 minutes" do
    travel_to "2024-05-01 12:00" do
      member = members(:aria)

      get member_path(member)
      assert_response :success

      travel 4.minutes

      get new_membership_path
      assert_response :success
      assert_select "select[name='membership[member_id]'] option[value='#{member.id}'][selected]", false
    end
  end

  test "malformed referer does not break new forms" do
    travel_to "2024-05-01 12:00" do
      get new_absence_path, headers: { "HTTP_REFERER" => "http://%zz" }

      assert_response :success
    end
  end
end

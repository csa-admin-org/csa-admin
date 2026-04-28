# frozen_string_literal: true

require "test_helper"

class BillingsControllerTest < ActionDispatch::IntegrationTest
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

  test "spreadsheets are served with no-store cache headers" do
    login(admins(:ultra))

    get billing_path(year: 2024)

    assert_response :success
    assert_no_store_download_headers
  end
end

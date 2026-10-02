# frozen_string_literal: true

require "test_helper"

class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
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

  test "new form links creating an announcement from the fieldset" do
    login admins(:super)

    get new_announcement_path

    assert_response :success
    assert_select "fieldset.inputs > ol > li.panel-actions a[href=?]",
      handbook_page_path("announcements", anchor: "creating")
  end
end

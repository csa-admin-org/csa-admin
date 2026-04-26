# frozen_string_literal: true

require "test_helper"

class Members::NewsletterDeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  def login_as_admin_originated(member, admin: admins(:ultra))
    session = Session.create!(
      admin: admin,
      member: member,
      email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  test "index shows the member email in the unsubscribe banner for an admin-originated session" do
    member = members(:john)
    EmailSuppression.suppress!(member.emails_array.first,
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Customer")

    login_as_admin_originated(member)

    get members_newsletter_deliveries_path

    assert_response :success
    assert_select "form[action='#{members_email_suppression_path}']"
    assert_includes response.body, member.emails_array.first
  end

  test "resubscribe is blocked for an admin-originated session" do
    member = members(:john)
    EmailSuppression.suppress!(member.emails_array.first,
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Customer")
    login_as_admin_originated(member)

    assert_no_difference -> {
      EmailSuppression.active.where(email: member.emails_array.first, stream_id: "broadcast").count
    } do
      delete members_email_suppression_path,
        headers: { "HTTP_REFERER" => members_newsletter_deliveries_path }
    end

    assert_redirected_to members_newsletter_deliveries_path
    assert_equal I18n.t("members.read_only_sessions.alert"), flash[:alert]
  end
end

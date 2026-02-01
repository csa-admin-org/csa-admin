# frozen_string_literal: true

require "test_helper"

class Members::DeletionRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  test "new requires authentication" do
    get new_members_account_deletion_request_path

    assert_redirected_to members_login_path
  end

  test "new renders deletion request page for eligible member" do
    member = members(:mary) # inactive member
    login(member)

    get new_members_account_deletion_request_path

    assert_response :success
    assert_select "h1", I18n.t("members.deletion_requests.new.title")
    assert_select "button", I18n.t("members.deletion_requests.new.request_code")
  end

  test "new renders page with ineligibility reasons for ineligible member" do
    member = members(:john) # active member
    login(member)

    get new_members_account_deletion_request_path

    assert_response :success
    assert_select "h1", I18n.t("members.deletion_requests.new.title")
    assert_select "a", I18n.t("members.deletion_requests.new.back")
    # Should not show the request code button for ineligible members
    assert_select "button", { count: 0, text: I18n.t("members.deletion_requests.new.request_code") }
    # Should show reason why deletion is not possible
    assert_select "li", I18n.t("members.deletion_requests.new.reasons.not_inactive")
  end

  test "new shows reason when member has open invoices" do
    member = members(:mary) # inactive member
    Invoice.create!(member: member, date: Date.current, entity_type: "AnnualFee", annual_fee: 30)
    perform_enqueued_jobs
    login(member)

    get new_members_account_deletion_request_path

    assert_response :success
    assert_select "li", I18n.t("members.deletion_requests.new.reasons.open_invoices")
  end

  test "create requires authentication" do
    post members_account_deletion_request_path

    assert_redirected_to members_login_path
  end

  test "create redirects ineligible member back with alert" do
    member = members(:john) # active member
    login(member)

    assert_enqueued_emails 0 do
      post members_account_deletion_request_path
    end

    assert_redirected_to new_members_account_deletion_request_path
    assert_equal I18n.t("members.deletion_requests.new.not_eligible"), flash[:alert]
  end

  test "create sends confirmation email and redirects to confirmation page" do
    member = members(:mary)
    login(member)

    assert_enqueued_emails 1 do
      post members_account_deletion_request_path
    end

    assert_redirected_to new_members_account_deletion_confirmation_path
  end

  test "create touches session updated_at" do
    member = members(:mary)
    session = login(member)
    original_updated_at = session.updated_at

    travel 1.second do
      post members_account_deletion_request_path
    end

    assert_not_equal original_updated_at, session.reload.updated_at
  end

  test "create sends email with 6-digit code" do
    member = members(:mary)
    login(member)

    post members_account_deletion_request_path
    perform_enqueued_jobs

    assert_equal 1, ActionMailer::Base.deliveries.size
    email = ActionMailer::Base.deliveries.last
    assert_equal [ member.emails_array.first ], email.to
    assert_equal I18n.t("session_mailer.deletion_confirmation_email.subject"), email.subject
    # Check both text and html parts for the code
    body_text = email.body.parts.map(&:body).join(" ")
    assert_match(/\d{6}/, body_text)
  end

  test "create uses member's language for email" do
    org(languages: %w[en fr])
    member = members(:mary)
    member.update!(language: "fr")
    login(member)

    post members_account_deletion_request_path
    perform_enqueued_jobs

    email = ActionMailer::Base.deliveries.last
    I18n.with_locale(:fr) do
      assert_equal I18n.t("session_mailer.deletion_confirmation_email.subject"), email.subject
    end
  end
end

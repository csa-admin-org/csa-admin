# frozen_string_literal: true

require "test_helper"

class Members::DeletionConfirmationsControllerTest < ActionDispatch::IntegrationTest
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

  def request_deletion_code(member)
    session = login(member)
    post members_account_deletion_request_path
    session.reload
    session
  end

  test "new requires authentication" do
    get new_members_account_deletion_confirmation_path

    assert_redirected_to members_login_path
  end

  test "new renders confirmation page" do
    member = members(:mary)
    request_deletion_code(member)

    get new_members_account_deletion_confirmation_path

    assert_response :success
    assert_select "h1", I18n.t("members.deletion_confirmations.new.title")
    assert_select "input[name='code']"
    assert_select "input[type='submit'][value=?]", I18n.t("members.deletion_confirmations.new.confirm")
  end

  test "new shows what happens explanation" do
    member = members(:mary)
    request_deletion_code(member)

    get new_members_account_deletion_confirmation_path

    assert_response :success
    assert_select "li", I18n.t("members.deletion_confirmations.new.what_happens.immediate_logout")
    assert_select "li", I18n.t("members.deletion_confirmations.new.what_happens.anonymization_delay")
    assert_select "li", I18n.t("members.deletion_confirmations.new.what_happens.invoices_retained")
  end

  test "create requires authentication" do
    post members_account_deletion_confirmation_path, params: { code: "123456" }

    assert_redirected_to members_login_path
  end

  test "create redirects ineligible member back with alert" do
    member = members(:john) # active member
    session = request_deletion_code(member)
    code = DeletionCode.generate(session)

    post members_account_deletion_confirmation_path, params: { code: code }

    assert_redirected_to new_members_account_deletion_request_path
    assert_equal I18n.t("members.deletion_requests.new.not_eligible"), flash[:alert]
    assert_not member.reload.discarded?
  end

  test "create with valid code discards member and redirects to goodbye" do
    member = members(:mary)
    session = request_deletion_code(member)
    code = DeletionCode.generate(session)

    post members_account_deletion_confirmation_path, params: { code: code }

    assert_redirected_to members_public_page_path("goodbye")
    assert member.reload.discarded?
    assert session.reload.revoked?
  end

  test "create with invalid code redirects to deletion request with alert" do
    member = members(:mary)
    request_deletion_code(member)

    post members_account_deletion_confirmation_path, params: { code: "000000" }

    assert_redirected_to new_members_account_deletion_request_path
    assert_equal I18n.t("members.deletion_confirmations.create.flash.invalid_code"), flash[:alert]
    assert_not member.reload.discarded?
  end

  test "create with expired code redirects to deletion request with alert" do
    member = members(:mary)
    session = request_deletion_code(member)
    code = DeletionCode.generate(session)

    travel 16.minutes do
      post members_account_deletion_confirmation_path, params: { code: code }
    end

    assert_redirected_to new_members_account_deletion_request_path
    assert_equal I18n.t("members.deletion_confirmations.create.flash.invalid_code"), flash[:alert]
    assert_not member.reload.discarded?
  end

  test "create deletes session cookie on success" do
    member = members(:mary)
    session = request_deletion_code(member)
    code = DeletionCode.generate(session)

    post members_account_deletion_confirmation_path, params: { code: code }

    assert_redirected_to members_public_page_path("goodbye")

    # Trying to access a protected page should redirect to login
    get members_account_path
    assert_redirected_to members_login_path
  end

  test "create with blank code redirects with alert" do
    member = members(:mary)
    request_deletion_code(member)

    post members_account_deletion_confirmation_path, params: { code: "" }

    assert_redirected_to new_members_account_deletion_request_path
    assert_equal I18n.t("members.deletion_confirmations.create.flash.invalid_code"), flash[:alert]
  end

  test "create with whitespace-padded valid code works" do
    member = members(:mary)
    session = request_deletion_code(member)
    code = DeletionCode.generate(session)

    post members_account_deletion_confirmation_path, params: { code: "  #{code}  " }

    assert_redirected_to members_public_page_path("goodbye")
    assert member.reload.discarded?
  end
end

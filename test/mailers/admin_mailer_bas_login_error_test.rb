# frozen_string_literal: true

require "test_helper"

class AdminMailerBASLoginErrorTest < ActionMailer::TestCase
  setup do
    BankConnection.delete_all
  end

  test "bas_login_error_email includes contract number and password form link" do
    admin = admins(:super)
    connection = bas_connection

    mail = AdminMailer.with(admin: admin, connection: connection).bas_login_error_email

    assert_equal [ admin.email ], mail.to
    assert_equal "⚠️ ABS login failed", mail.subject
    assert_equal "admin-bas-login-error", mail.tag
    body = mail.body.to_s
    assert_includes body, "Hello Acme Super Admin,"
    assert_includes body, "<strong>IB0043999</strong>"
    assert_includes body, "https://admin.acme.test/bank_connections/edit_bas_password"
    assert_includes body, "https://admin.acme.test/support"
    assert_includes body, "Update the password"
    assert_not_includes body, "https://admin.acme.test/settings#bank_connection"
    assert_not_includes body, "old-secret"
  end

  test "bas_login_error_email preview renders" do
    I18n.locale = :en
    mail = AdminMailerPreview.new.bas_login_error_email

    assert_equal [ "admin@csa-admin.org" ], mail.to
    assert_equal "⚠️ ABS login failed", mail.subject
    body = mail.body.to_s
    assert_includes body, "<strong>IB0043999</strong>"
    assert_includes body, "Update the password"
    assert_includes body, "https://admin.acme.test/bank_connections/edit_bas_password"
    assert_not_includes body, "PREVIEW_SECRET"
  end

  test "demo interceptor blocks BAS login error mail" do
    with_tenant("demo-en") do
      message = Mail.new(to: "test@example.com", from: "sender@example.com")
      message[:tag] = "admin-bas-login-error"

      DemoMailInterceptor.delivering_email(message)

      assert_not message.perform_deliveries
    end
  end

  private

  def bas_connection
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      health_status: "errored",
      last_error_class: "Billing::BAS::LoginError",
      credentials: {
        account_number: "346.578.101-00",
        contract_number: "IB0043999",
        contract_password: "old-secret"
      })
  end
end

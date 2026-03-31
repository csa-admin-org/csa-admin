# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ApplicationMailerTest < ActionMailer::TestCase
  test "default_from uses organization email and name" do
    mail = AdminMailer.with(
      admin: admins(:ultra),
      member: members(:john)
    ).new_registration_email

    assert_equal "Acme <info@acme.test>", mail[:from].decoded
  end

  test "default_from uses demo email when tenant is demo" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        mail = AdminMailer.with(
          admin: admins(:ultra),
          member: members(:john)
        ).new_registration_email

        assert_equal "CSA Admin <info@csa-admin.org>", mail[:from].decoded
      end
    end
  end
  test "unwraps action-text-attachment elements" do
    content = <<~HTML
      <p>Hello</p>
      <action-text-attachment sgid="abc" content-type="image/jpeg" width="3508" height="4961" presentation="gallery">
        <div class="attachment attachment--preview">
          <img src="https://example.com/image.jpg" />
        </div>
      </action-text-attachment>
    HTML

    mailer = ApplicationMailer.new
    result = mailer.send(:sanitize_action_text_for_email, content)

    assert_no_match(/<action-text-attachment/, result)
    assert_no_match(%r{</action-text-attachment>}, result)
    assert_includes result, '<div class="attachment attachment--preview">'
    assert_includes result, '<img src="https://example.com/image.jpg" />'
  end

  test "unwraps multiple action-text-attachments" do
    content = <<~HTML
      <action-text-attachment width="3508" height="4961"><div class="attachment">img1</div></action-text-attachment>
      <action-text-attachment width="800" height="600"><div class="attachment">img2</div></action-text-attachment>
    HTML

    mailer = ApplicationMailer.new
    result = mailer.send(:sanitize_action_text_for_email, content)

    assert_no_match(/<action-text-attachment/, result)
    assert_includes result, "img1"
    assert_includes result, "img2"
  end

  test "does not affect other elements" do
    content = '<img src="logo.png" width="100" height="100" />'

    mailer = ApplicationMailer.new
    result = mailer.send(:sanitize_action_text_for_email, content)

    assert_equal content, result
  end
end

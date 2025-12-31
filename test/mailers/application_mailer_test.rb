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
      with_env("ULTRA_ADMIN_EMAIL" => "demo@csa-admin.org") do
        mail = AdminMailer.with(
          admin: admins(:ultra),
          member: members(:john)
        ).new_registration_email

        assert_equal "CSA Admin Demo <demo@csa-admin.org>", mail[:from].decoded
      end
    end
  end
end

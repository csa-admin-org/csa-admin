# frozen_string_literal: true

require "test_helper"

class Notification::DemoRegistrationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "sends notification to meaningfully engaged demo admin after one hour" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        admin = create_demo_admin(created_at: 2.hours.ago, demo_message: "Green Valley CSA")
        create_page_visit(admin, page_key: "dashboard#index")
        create_page_visit(admin, page_key: "members#index")
        create_page_visit(admin, page_key: "admins#index")

        assert_enqueued_emails 1 do
          Notification::DemoRegistration.notify
        end

        assert_not_nil admin.reload.demo_registration_notification_sent_at
      end
    end
  end

  test "does not send before one hour" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        admin = create_demo_admin(created_at: 30.minutes.ago)
        create_page_visit(admin, page_key: "members#index")
        create_page_visit(admin, page_key: "admins#index")

        assert_no_enqueued_emails do
          Notification::DemoRegistration.notify
        end

        assert_nil admin.reload.demo_registration_notification_sent_at
      end
    end
  end

  test "does not send without enough meaningful page visits" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        admin = create_demo_admin(created_at: 2.hours.ago)
        create_page_visit(admin, page_key: "dashboard#index")
        create_page_visit(admin, page_key: "members#index")

        assert_no_enqueued_emails do
          Notification::DemoRegistration.notify
        end

        assert_nil admin.reload.demo_registration_notification_sent_at
      end
    end
  end

  test "does not send without enough distinct pages" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        admin = create_demo_admin(created_at: 2.hours.ago)
        create_page_visit(admin, page_key: "members#index")
        create_page_visit(admin, page_key: "members#index")

        assert_no_enqueued_emails do
          Notification::DemoRegistration.notify
        end

        assert_nil admin.reload.demo_registration_notification_sent_at
      end
    end
  end

  test "does not send twice" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        admin = create_demo_admin(
          created_at: 2.hours.ago,
          demo_registration_notification_sent_at: 1.hour.ago)
        create_page_visit(admin, page_key: "members#index")
        create_page_visit(admin, page_key: "admins#index")

        assert_no_enqueued_emails do
          Notification::DemoRegistration.notify
        end
      end
    end
  end

  test "does not send to ultra admin" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "ultra@example.com") do
        admin = create_demo_admin(email: "ultra@example.com", created_at: 2.hours.ago)
        create_page_visit(admin, page_key: "members#index")
        create_page_visit(admin, page_key: "admins#index")

        assert_no_enqueued_emails do
          Notification::DemoRegistration.notify
        end

        assert_nil admin.reload.demo_registration_notification_sent_at
      end
    end
  end

  test "does nothing for non-demo tenants" do
    with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
      admin = create_demo_admin(created_at: 2.hours.ago)
      create_page_visit(admin, page_key: "members#index")
      create_page_visit(admin, page_key: "admins#index")

      assert_no_enqueued_emails do
        Notification::DemoRegistration.notify
      end

      assert_nil admin.reload.demo_registration_notification_sent_at
    end
  end

  private

  def create_demo_admin(name: "Alice", email: "alice@example.com", language: "en", **attrs)
    Admin.create!(
      name: name,
      email: email,
      language: language,
      permission: permissions(:super_admin),
      **attrs)
  end

  def create_page_visit(admin, page_key:)
    session = admin.sessions.first || Session.create!(
      admin: admin,
      email: admin.email,
      user_agent: "Mozilla/5.0",
      remote_addr: "127.0.0.1")

    Demo::PageVisit.create!(
      admin: admin,
      session: session,
      path: "/#{page_key.split("#").first}",
      controller_name: page_key.split("#").first,
      action_name: page_key.split("#").last,
      page_key: page_key,
      status: 200)
  end
end

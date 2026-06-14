# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Notification::DemoFollowUpTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def create_demo_admin(name: "Alice", email: "alice@example.com", language: "en", **attrs)
    Admin.create!(
      name: name,
      email: email,
      language: language,
      permission: permissions(:super_admin),
      **attrs)
  end

  def create_used_session(admin:, last_used_at: 2.days.ago)
    Session.create!(
      admin: admin,
      email: admin.email,
      user_agent: "Mozilla/5.0",
      remote_addr: "127.0.0.1",
      last_used_at: last_used_at)
  end

  def create_page_visit(admin:, session:, page_key:, created_at: 2.days.ago)
    travel_to created_at do
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

  test "sends follow-up to eligible demo admin" do
    Tenant.stub(:demo?, true) do
      Tenant.stub(:admin_host, "admin.demo-en.csa-admin.org") do
        admin = create_demo_admin
        session = create_used_session(admin: admin, last_used_at: 25.hours.ago)
        create_page_visit(admin: admin, session: session, page_key: "dashboard#index", created_at: 25.hours.ago)
        create_page_visit(admin: admin, session: session, page_key: "members#index", created_at: 25.hours.ago)
        create_page_visit(admin: admin, session: session, page_key: "admins#index", created_at: 25.hours.ago)

        with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
          assert_enqueued_emails 2 do
            Notification::DemoFollowUp.notify
          end

          assert_not_nil admin.reload.demo_follow_up_sent_at
        end
      end
    end
  end

  test "does not send to admin who never logged in" do
    Tenant.stub(:demo?, true) do
      admin = create_demo_admin

      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        assert_no_enqueued_emails do
          Notification::DemoFollowUp.notify
        end

        assert_nil admin.reload.demo_follow_up_sent_at
      end
    end
  end

  test "does not send to admin who logged in but never visited pages" do
    Tenant.stub(:demo?, true) do
      admin = create_demo_admin
      create_used_session(admin: admin, last_used_at: 2.days.ago)

      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        assert_no_enqueued_emails do
          Notification::DemoFollowUp.notify
        end

        assert_nil admin.reload.demo_follow_up_sent_at
      end
    end
  end

  test "does not send to admin who logged in less than 24 hours ago" do
    Tenant.stub(:demo?, true) do
      admin = create_demo_admin
      session = create_used_session(admin: admin, last_used_at: 23.hours.ago)
      create_page_visit(admin: admin, session: session, page_key: "members#index", created_at: 23.hours.ago)
      create_page_visit(admin: admin, session: session, page_key: "admins#index", created_at: 23.hours.ago)

      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        assert_no_enqueued_emails do
          Notification::DemoFollowUp.notify
        end

        assert_nil admin.reload.demo_follow_up_sent_at
      end
    end
  end

  test "does not send to admin who already received follow-up" do
    Tenant.stub(:demo?, true) do
      admin = create_demo_admin(demo_follow_up_sent_at: 1.day.ago)
      session = create_used_session(admin: admin, last_used_at: 2.days.ago)
      create_page_visit(admin: admin, session: session, page_key: "members#index")
      create_page_visit(admin: admin, session: session, page_key: "admins#index")

      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        assert_no_enqueued_emails do
          Notification::DemoFollowUp.notify
        end
      end
    end
  end

  test "does not send to admin who contacted support" do
    Tenant.stub(:demo?, true) do
      admin = create_demo_admin
      session = create_used_session(admin: admin, last_used_at: 2.days.ago)
      create_page_visit(admin: admin, session: session, page_key: "members#index")
      create_page_visit(admin: admin, session: session, page_key: "admins#index")
      Support::Ticket.create!(
        admin: admin,
        subject: "Help",
        content: "I need help",
        priority: :normal)

      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        perform_enqueued_jobs # flush the ticket notification email

        assert_no_enqueued_emails do
          Notification::DemoFollowUp.notify
        end

        assert_nil admin.reload.demo_follow_up_sent_at
      end
    end
  end

  test "does not send to ultra admin" do
    Tenant.stub(:demo?, true) do
      with_env("ULTRA_ADMIN_EMAIL" => "ultra@example.com") do
        admin = create_demo_admin(email: "ultra@example.com")
        session = create_used_session(admin: admin, last_used_at: 2.days.ago)
        create_page_visit(admin: admin, session: session, page_key: "members#index")
        create_page_visit(admin: admin, session: session, page_key: "admins#index")

        assert_no_enqueued_emails do
          Notification::DemoFollowUp.notify
        end

        assert_nil admin.reload.demo_follow_up_sent_at
      end
    end
  end

  test "does nothing for non-demo tenants" do
    admin = create_demo_admin
    session = create_used_session(admin: admin, last_used_at: 2.days.ago)
    create_page_visit(admin: admin, session: session, page_key: "members#index")
    create_page_visit(admin: admin, session: session, page_key: "admins#index")

    with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
      assert_no_enqueued_emails do
        Notification::DemoFollowUp.notify
      end

      assert_nil admin.reload.demo_follow_up_sent_at
    end
  end
end

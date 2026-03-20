# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Demo::RegistrationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "valid registration creates admin with superadmin permission" do
    in_demo_tenant do
      registration = Demo::Registration.new(
        name: "Alice Johnson",
        email: "alice@example.com",
        note: "Green Valley CSA")

      assert_enqueued_emails 2 do
        assert registration.save
      end

      admin = Admin.find_by(email: "alice@example.com")
      assert admin
      assert_equal "Alice Johnson", admin.name
      assert_equal "en", admin.language
      assert_equal Permission.superadmin, admin.permission
    end
  end

  test "valid registration without note" do
    in_demo_tenant do
      registration = Demo::Registration.new(
        name: "Bob Smith",
        email: "bob@example.com")

      assert_enqueued_emails 2 do
        assert registration.save
      end
    end
  end

  test "uses demo tenant language for admin" do
    in_demo_tenant(language: "fr", host: "admin.acp-admin.ch") do
      registration = Demo::Registration.new(
        name: "Claire Dupont",
        email: "claire@example.com")

      assert_enqueued_emails 2 do
        registration.save
      end

      admin = Admin.find_by(email: "claire@example.com")
      assert_equal "fr", admin.language
    end
  end

  test "normalizes email to lowercase and strips whitespace" do
    in_demo_tenant do
      registration = Demo::Registration.new(
        name: "Dan Test",
        email: "  Dan@Example.COM  ")

      assert_enqueued_emails 2 do
        registration.save
      end

      assert Admin.exists?(email: "dan@example.com")
    end
  end

  test "strips whitespace from name" do
    in_demo_tenant do
      registration = Demo::Registration.new(
        name: "  Eve Tester  ",
        email: "eve@example.com")

      assert_enqueued_emails 2 do
        registration.save
      end

      admin = Admin.find_by(email: "eve@example.com")
      assert_equal "Eve Tester", admin.name
    end
  end

  test "invalid without name" do
    in_demo_tenant do
      registration = Demo::Registration.new(email: "test@example.com")

      assert_not registration.save
      assert_includes registration.errors[:name], I18n.t("errors.messages.blank")
    end
  end

  test "invalid without email" do
    in_demo_tenant do
      registration = Demo::Registration.new(name: "Test User")

      assert_not registration.save
      assert_includes registration.errors[:email], I18n.t("errors.messages.blank")
    end
  end

  test "invalid with malformed email" do
    in_demo_tenant do
      registration = Demo::Registration.new(
        name: "Test User",
        email: "not-an-email")

      assert_not registration.save
      assert_includes registration.errors[:email], I18n.t("errors.messages.invalid")
    end
  end

  test "invalid when email already exists" do
    in_demo_tenant do
      Admin.create!(
        name: "Existing",
        email: "existing@example.com",
        language: "en",
        permission: Permission.superadmin)

      registration = Demo::Registration.new(
        name: "Another User",
        email: "existing@example.com")

      assert_not registration.save
      assert_includes registration.errors[:email], I18n.t("errors.messages.taken")
    end
  end

  test "three-letter name with distinct letters creates admin" do
    in_demo_tenant do
      registration = Demo::Registration.new(
        name: "Joe",
        email: "joe@example.com")

      assert_enqueued_emails 2 do
        assert registration.save
      end

      assert Admin.exists?(email: "joe@example.com")
    end
  end

  test "creates a session for direct access via magic link" do
    in_demo_tenant do
      registration = Demo::Registration.new(
        name: "Frank Test",
        email: "frank@example.com")

      assert_difference "Session.count", 1 do
        assert_enqueued_emails 2 do
          registration.save
        end
      end

      admin = Admin.find_by(email: "frank@example.com")
      session = admin.sessions.last
      assert session
      assert_equal "127.0.0.1", session.remote_addr
      assert_equal "-", session.user_agent
    end
  end

  test "enqueues notification email to ultra admin" do
    in_demo_tenant do
      with_env("ULTRA_ADMIN_EMAIL" => "info@csa-admin.org") do
        registration = Demo::Registration.new(
          name: "Grace Test",
          email: "grace@example.com",
          note: "Happy Farm")

        assert_enqueued_emails 2 do
          registration.save
        end
      end
    end
  end

  test "does not create admin when validation fails" do
    in_demo_tenant do
      initial_count = Admin.count

      registration = Demo::Registration.new(
        name: "",
        email: "test@example.com")

      assert_no_enqueued_emails do
        assert_not registration.save
      end

      assert_equal initial_count, Admin.count
    end
  end

  private

  def in_demo_tenant(language: "en", host: "admin.csa-admin.org")
    Tenant.stub(:demo?, true) do
      Tenant.stub(:demo_language, language) do
        Tenant.stub(:admin_host, host) do
          yield
        end
      end
    end
  end
end

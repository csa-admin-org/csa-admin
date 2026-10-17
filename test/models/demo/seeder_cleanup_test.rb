# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Demo::SeederCleanupTest < ActiveSupport::TestCase
  test "removes never-used admins older than the invite window and keeps recent ones" do
    Tenant.stub(:demo?, true) do
      Tenant.stub(:demo_language, "en") do
        Tenant.stub(:admin_host, "admin.csa-admin.org") do
          with_env("ULTRA_ADMIN_EMAIL" => admins(:ultra).email) do
            stale = create_demo_admin("stale@example.com", created_at: 3.weeks.ago)
            recent = create_demo_admin("recent@example.com", created_at: 1.week.ago)
            active = create_demo_admin("active@example.com", created_at: 3.weeks.ago)
            create_session(active, last_used_at: 1.day.ago)
            inactive = create_demo_admin("inactive@example.com", created_at: 1.year.ago)
            create_session(inactive, last_used_at: 7.months.ago)
            unopened = create_demo_admin("unopened@example.com", created_at: 3.weeks.ago)
            create_session(unopened, last_used_at: nil)

            Demo::Seeder.new.send(:cleanup_inactive_admins!)

            assert_not Admin.exists?(stale.id)
            assert_not Admin.exists?(inactive.id)
            assert_not Admin.exists?(unopened.id)
            assert Admin.exists?(recent.id)
            assert Admin.exists?(active.id)
            assert Admin.exists?(admins(:ultra).id)
          end
        end
      end
    end
  end

  private

  def create_demo_admin(email, created_at:)
    admin = Admin.create!(
      name: "Demo Admin",
      email: email,
      language: "en",
      permission: permissions(:super_admin))
    admin.update_columns(created_at: created_at, updated_at: created_at)
    admin
  end

  def create_session(admin, last_used_at:)
    session = Session.create!(
      admin: admin,
      email: admin.email,
      user_agent: "Mozilla/5.0",
      remote_addr: "127.0.0.1")
    session.update_columns(last_used_at: last_used_at) if last_used_at
    session
  end
end

# frozen_string_literal: true

require "test_helper"
require "rake"

class TenantRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("tenant:remove")
    %w[tenant:remove cap:delete postmark:delete litestream:clear].each do |name|
      Rake::Task[name].reenable
    end
  end

  test "tenant:remove passes TENANT and CONFIRM to Tenant::Remover" do
    called = nil
    fake_remover = Object.new
    fake_remover.define_singleton_method(:run) { called = :run }

    with_env("TENANT" => "retired", "CONFIRM" => "retired") do
      Tenant::Remover.stub(:new, ->(tenant, confirm:) {
        assert_equal "retired", tenant
        assert_equal "retired", confirm
        fake_remover
      }) do
        Rake::Task["tenant:remove"].invoke
      end
    end

    assert_equal :run, called
  end

  test "cap:delete reminds to pass CONFIRM on dry-run" do
    fake_remover = Object.new
    fake_remover.define_singleton_method(:tenant) { "acme" }
    fake_remover.define_singleton_method(:confirmed?) { false }
    fake_remover.define_singleton_method(:delete_cap_keys) { puts "dry-run Cap" }

    out, = with_env("TENANT" => "acme", "CONFIRM" => nil) do
      Tenant::Remover.stub(:new, fake_remover) do
        capture_io { Rake::Task["cap:delete"].invoke }
      end
    end

    assert_includes out, "dry-run Cap"
    assert_includes out, "Re-run with CONFIRM=acme to delete."
  end

  test "postmark:delete executes without reminder when confirmed" do
    fake_remover = Object.new
    fake_remover.define_singleton_method(:tenant) { "acme" }
    fake_remover.define_singleton_method(:confirmed?) { true }
    fake_remover.define_singleton_method(:delete_postmark) { puts "deleted Postmark" }

    out, = with_env("TENANT" => "acme", "CONFIRM" => "acme") do
      Tenant::Remover.stub(:new, fake_remover) do
        capture_io { Rake::Task["postmark:delete"].invoke }
      end
    end

    assert_includes out, "deleted Postmark"
    assert_not_includes out, "Re-run with CONFIRM"
  end

  test "litestream:clear delegates to Tenant::Remover" do
    fake_remover = Object.new
    fake_remover.define_singleton_method(:tenant) { "retired" }
    fake_remover.define_singleton_method(:confirmed?) { false }
    fake_remover.define_singleton_method(:clear_litestream_replica) { puts "dry-run Litestream" }

    out, = with_env("TENANT" => "retired", "CONFIRM" => nil) do
      Tenant::Remover.stub(:new, fake_remover) do
        capture_io { Rake::Task["litestream:clear"].invoke }
      end
    end

    assert_includes out, "dry-run Litestream"
    assert_includes out, "Re-run with CONFIRM=retired to delete."
  end
end

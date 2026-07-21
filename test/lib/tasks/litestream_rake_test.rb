# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "rake"
require "tmpdir"

class LitestreamRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("litestream:restore")
    Rake::Task["litestream:restore"].reenable
  end

  test "restore reports all tenants without listing them" do
    out, = run_restore

    assert_includes out, "Restoring litestream backups for all tenants..."
    assert_not_includes out, "acme, demo"
  end

  test "restore reports selected tenants" do
    out, = run_restore(tenant: "acme,demo")

    assert_includes out, "Restoring litestream backups for: acme, demo"
  end

  private

  def run_restore(tenant: nil)
    Dir.mktmpdir do |dir|
      with_env("BACKUP_PATH" => dir, "TENANT" => tenant) do
        with_rails_env("development") do
          Rails.stub(:root, Pathname(dir)) do
            Tenant.stub(:all, %w[acme demo]) do
              Parallel.stub(:each, ->(*) { }) do
                capture_io { Rake::Task["litestream:restore"].invoke }
              end
            end
          end
        end
      end
    end
  end
end

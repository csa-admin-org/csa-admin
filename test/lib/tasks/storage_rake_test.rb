# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "rake"
require "tmpdir"

class StorageRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("storage:restore")
    Rake::Task["storage:restore"].reenable
  end

  test "restore keeps copied backup files and removes stale files" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      backup_path = root.join("backup")
      keys = %w[abcdefgh12345678 efghijkl12345678]
      create_backup_files(backup_path, keys)
      stale_file = create_stale_file(root)
      create_application_record_stub(root)

      out, = run_restore(root, backup_path)

      assert_includes out, "Restoring storage for all tenants..."
      keys.each do |key|
        assert_equal key, restored_file(root, key).binread
      end
      assert_not stale_file.exist?
    end
  end

  test "restore reports selected tenants" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      backup_path = root.join("backup")
      create_application_record_stub(root)

      out, = run_restore(root, backup_path, tenant: "acme,demo", tenants: %w[acme demo])

      assert_includes out, "Restoring storage for: acme, demo"
    end
  end

  private

  def create_backup_files(backup_path, keys)
    keys.each do |key|
      file = backup_path.join("storage/acme", key)
      FileUtils.mkdir_p(file.dirname)
      file.binwrite(key)
    end
  end

  def create_stale_file(root)
    file = root.join("storage/acme/st/al/stale")
    FileUtils.mkdir_p(file.dirname)
    file.binwrite("stale")
    file
  end

  def create_application_record_stub(root)
    file = root.join("app/models/application_record.rb")
    FileUtils.mkdir_p(file.dirname)
    file.write("# frozen_string_literal: true\n")
  end

  def run_restore(root, backup_path, tenant: nil, tenants: [ "acme" ])
    with_env("BACKUP_PATH" => backup_path.to_s, "TENANT" => tenant) do
      with_rails_env("development") do
        Rails.stub(:root, root) do
          Tenant.stub(:all, tenants) do
            Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
              ActiveStorage::Blob.stub(:update_all, nil) do
                capture_io { Rake::Task["storage:restore"].invoke }
              end
            end
          end
        end
      end
    end
  end

  def restored_file(root, key)
    root.join("storage/acme", key[0..1], key[2..3], key)
  end
end

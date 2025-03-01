# frozen_string_literal: true

require "fileutils"
require "parallel"

namespace :storage do
  desc "Copy attachments from local backup to storage directory"
  task restore: :environment do
    raise "Only run this task in dev!" unless Rails.env.development?

    backup_folder = ENV.fetch("BACKUP_PATH") + "/storage"
    storage_folder = Rails.root.join("storage")

    Parallel.each(Dir.glob("#{backup_folder}/**/*")) do |file|
      next if File.directory?(file)

      relative_path = file.sub("#{backup_folder}/", "")
      tenant, key = relative_path.split("/")
      first_two = key[0..1]
      next_two = key[2..3]

      target_path = File.join(storage_folder, tenant, first_two, next_two, key)
      unless File.exist?(target_path)
        FileUtils.mkdir_p(File.dirname(target_path))
        FileUtils.cp(file, target_path)
      end
    end

    # Ensure the tenant shards are connected.
    require Rails.root.join("app/models/application_record")
    Parallel.each(Tenant.all) do |tenant|
      Tenant.switch(tenant) do
        ActiveStorage::Blob.update_all(service_name: "tenant_disk")
      end
    end

    puts "Storage backups restored successfully."
  end
end

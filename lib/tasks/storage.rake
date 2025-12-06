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

  desc "Clear all attachments for a tenant from object storage"
  task clear: :environment do
    tenant_name = ENV["TENANT_NAME"]
    raise "TENANT_NAME environment variable is required" if tenant_name.blank?

    puts "WARNING: This will permanently delete all files in 'csa-admin-storage/#{tenant_name}/'."
    puts "Type the tenant name '#{tenant_name}' to confirm:"
    confirmation = $stdin.gets.chomp

    unless confirmation == tenant_name
      puts "Confirmation failed. Aborting."
      exit 1
    end

    creds = Rails.application.credentials.dig(:object_store, :production)
    client = Aws::S3::Client.new(
      endpoint: creds[:endpoint],
      access_key_id: creds[:access_key_id],
      secret_access_key: creds[:secret_access_key],
      region: creds[:region] || "auto"
    )
    bucket = Aws::S3::Bucket.new("csa-admin-storage", client: client)
    object_keys = bucket.objects(prefix: "#{tenant_name}/").map(&:key)
    total_count = object_keys.size

    if total_count.zero?
      puts "No objects found in '#{tenant_name}/'. Nothing to delete."
      exit 0
    end

    puts "\nFound #{total_count} objects to delete."
    puts "\nSample of objects:"
    object_keys.sample(10).each { |key| puts "  - #{key}" }

    puts "\nProceed with deletion? (Y/N)"
    final_confirmation = $stdin.gets.chomp

    unless final_confirmation.downcase == "y"
      puts "Aborted."
      exit 1
    end

    count = 0
    object_keys.each_slice(1000) do |batch|
      bucket.delete_objects(
        delete: { objects: batch.map { |key| { key: key } } }
      )
      count += batch.size
      print "\rDeleted #{count}/#{total_count} objects..."
    end

    puts "\nSuccessfully deleted #{count} objects from '#{tenant_name}/'."
  end
end

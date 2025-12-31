# frozen_string_literal: true

require "erb"
require "ostruct"

desc "Generate HTML bookmarks file for all tenants using ERB template"
task bookmarks: :environment do
  file_path = ENV["BOOKMARKS_PATH"] || Rails.root.join("tmp", "bookmarks.html")
  template_path = Rails.root.join("lib", "templates", "bookmarks.html.erb")
  template = File.read(template_path)

  @organizations = []
  Tenant.switch_each do |tenant|
    @organizations << OpenStruct.new(
      name: Current.org.name,
      tenant: tenant,
      production_admin_url: Current.org.admin_url(mc_login: true),
      production_members_url: Current.org.members_url,
      development_admin_url: Current.org.admin_url.gsub(/\.[a-z]+\z/, ".test"),
      development_members_url: Current.org.members_url.gsub(/\.[a-z]+\z/, ".test"))
  end

  html = ERB.new(template).result(binding)

  File.write(file_path, html)
  puts "Bookmarks file generated at: #{file_path}"
end

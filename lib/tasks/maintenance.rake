# frozen_string_literal: true

require "parallel"
require "faraday"
require "json"

namespace :maintenance do
  desc "Enable Cloudflare Worker-based maintenance page for all tenant hostnames"
  task on: :environment do
    zone_id     = ENV["CLOUDFLARE_ZONE_ID"] || abort("Missing CF_ZONE_ID")
    email       = ENV["CLOUDFLARE_EMAIL"] || abort("Missing CLOUDFLARE_EMAIL")
    api_key     = ENV["CLOUDFLARE_API_KEY"] || abort("Missing CLOUDFLARE_API_KEY")
    worker_name = "maintenance"
    client = CloudflareClient.new(email, api_key, zone_id)
    routes = client.worker_routes

    hostnames do |hostname|
      pattern = "#{hostname}/*"
      unless routes.any? { |r| r["pattern"] == pattern }
        client.create_worker_route(pattern, worker_name)
      end
      puts "#{hostname} ✅"
    end
  end

  desc "Disable Cloudflare Worker-based maintenance page for all tenant hostnames"
  task off: :environment do
    zone_id = ENV["CLOUDFLARE_ZONE_ID"] || abort("Missing CF_ZONE_ID")
    email   = ENV["CLOUDFLARE_EMAIL"] || abort("Missing CLOUDFLARE_EMAIL")
    api_key = ENV["CLOUDFLARE_API_KEY"] || abort("Missing CLOUDFLARE_API_KEY")
    client = CloudflareClient.new(email, api_key, zone_id)
    routes = client.worker_routes

    hostnames do |hostname|
      pattern = "#{hostname}/*"
      if route = routes.find { |r| r["pattern"] == pattern }
        client.delete_worker_route(route["id"])
      end
      puts "#{hostname} ✅"
    end
  end
end

def hostnames(&block)
  tenants = ENV["TENANT"] ? [ ENV["TENANT"] ] : Tenant.all
  Parallel.each(tenants) do |tenant|
    Tenant.switch(tenant) do
      Current.org.hostnames.each do |hostname|
        block.call(hostname)
      end
    end
  end
end

class CloudflareClient
  def initialize(email, api_key, zone_id)
    @client = Faraday.new("https://api.cloudflare.com/client/v4") do |f|
      f.request :url_encoded
      f.headers["X-Auth-Email"] = email
      f.headers["X-Auth-Key"]   = api_key
      f.headers["Content-Type"] = "application/json"
      f.adapter Faraday.default_adapter
    end
    @zone_id = zone_id
  end

  def worker_routes
    response = @client.get("zones/#{@zone_id}/workers/routes")
    handle_response(response)
  end

  def create_worker_route(pattern, worker_name)
    response = @client.post("zones/#{@zone_id}/workers/routes") do |req|
      req.body = {
        pattern: pattern,
        script:  worker_name
      }.to_json
    end
    handle_response(response)
  end

  def delete_worker_route(route_id)
    response = @client.delete("zones/#{@zone_id}/workers/routes/#{route_id}")
    handle_response(response)
  end

  private

  def handle_response(response)
    res = JSON.parse(response.body)
    if res["success"]
      res["result"]
    else
      raise "Error: #{res["errors"]}"
    end
  end
end

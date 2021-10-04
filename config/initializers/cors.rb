Rails.application.config.middleware.insert_before 0, Rack::Cors do
  if ENV['ASSET_HOST']
    allow do
      origins "#{ENV['ASSET_HOST']}:443"
      resource '*', headers: :any, methods: %i[get options head]
    end
  end
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '/assets/*', headers: :any, methods: %i[get options], credentials: false
    resource '/packs/*', headers: :any, methods: %i[get options], credentials: false
  end
end

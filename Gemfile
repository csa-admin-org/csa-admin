source 'https://rubygems.org'

ruby '2.3.0'

gem 'rails', '4.2.5.1'
gem 'rails-i18n'

source 'https://rails-assets.org' do
  gem 'rails-assets-highcharts'
end

gem 'passenger'
gem 'rack-status'

gem 'pg'
gem 'uniquify'
gem 'paranoia'
gem 'cancancan'

gem 'activeadmin', github: 'activeadmin'
gem 'responsive_active_admin'

gem 'turbolinks'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails'
gem 'momentjs-rails'
gem 'slim'
gem 'to_spreadsheet', github: 'farukca/to_spreadsheet', ref: '922b63'
gem 'active_admin_editor', github: 'thibaudgg/active_admin_editor'

gem 'sass-rails'
gem 'font-awesome-sass'

gem 'sucker_punch'
gem 'facets', require: false

gem 'bourbon'
gem 'bitters'
gem 'neat'
gem 'refills'

gem 'devise'
gem 'devise-i18n'

gem 'uglifier'
gem 'jbuilder'
gem 'google_drive'
gem 'google-api-client'
gem 'google_maps_geocoder'

gem 'icalendar'

gem 'exception_notification'
gem 'exception_notification-rake'

gem 'faraday'
gem 'faraday-cookie_jar'

gem 'prawn'
gem 'prawn-table'
gem 'carrierwave'
gem 'carrierwave-postgresql'

group :production do
  gem 'rails_12factor'
  gem 'dalli'
  gem 'skylight'
end

group :development do
  gem 'rack-livereload'
  gem 'guard-livereload', require: false
  gem 'quiet_assets'
  gem 'letter_opener'
  gem 'bullet'
end

group :development, :test do
  gem 'timecop'
  gem 'dotenv-rails'
  gem 'rspec-rails'
  gem 'spring-commands-rspec'
  gem 'capybara'
  gem 'capybara-email'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'pdf-inspector', require: 'pdf/inspector'
end

group :test do
  gem 'vcr'
  gem 'webmock'
end

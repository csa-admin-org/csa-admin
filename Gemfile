source 'https://rubygems.org'

ruby '2.1.5'

gem 'rails', '4.1.8'
gem 'rails-i18n'

gem 'passenger'
gem 'rack-status'

gem 'pg'
gem 'uniquify'
gem 'paranoia'
gem 'cancancan'

# gem 'foreigner'
# gem 'immigrant' # TODO

gem 'activeadmin', github: 'activeadmin'
gem 'responsive_active_admin'

gem 'turbolinks'
gem 'jquery-ui-rails'
gem 'slim'
gem 'to_spreadsheet'

gem 'sass-rails', '5.0.0.beta1'
gem 'font-awesome-sass'

gem 'bourbon'
gem 'bitters'
gem 'neat', '>= 1.7.0'
gem 'refills' #, github: 'thoughtbot/refills'

gem 'devise'
gem 'devise-i18n'

gem 'uglifier'
gem 'jbuilder'
gem 'google_drive'
gem 'google-api-client'

gem 'icalendar'

gem 'rails_12factor', group: :production
gem 'exception_notification'

group :production do
  gem 'dalli'
  gem 'newrelic_rpm'
  gem 'skylight'
end

group :development do
  gem 'rack-livereload'
  gem 'guard-livereload', require: false
  gem 'quiet_assets'
  gem 'letter_opener'
end

group :development, :test do
  gem 'dotenv-rails'
  gem 'rspec-rails'
  gem 'spring-commands-rspec'
  gem 'capybara'
  gem 'capybara-email'
  gem 'factory_girl_rails'
  gem 'faker'
end

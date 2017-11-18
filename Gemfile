source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '2.4.1'

gem 'rails', '5.1.3'
gem 'rails-i18n'
gem 'puma'

source 'https://rails-assets.org' do
  gem 'rails-assets-highcharts'
end

gem 'rack-status'

gem 'pg'
gem 'uniquify'
gem 'paranoia'
gem 'cancancan'

gem 'activeadmin'
gem 'formadmin'

gem 'turbolinks'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails'
gem 'momentjs-rails'
gem 'slim'
gem 'to_spreadsheet', github: 'farukca/to_spreadsheet', ref: '922b63'
gem 'axlsx', github: 'randym/axlsx'
gem 'active_admin_editor', github: 'thibaudgg/active_admin_editor'

gem 'sass-rails'
gem 'font-awesome-sass'

gem 'sucker_punch'

gem 'bourbon', '~> 4.2.7'
gem 'bitters', '~> 1.2.0'
gem 'neat', '~> 1.8'
gem 'refills'

gem 'devise'
gem 'devise-i18n'

gem 'uglifier'
gem 'jbuilder'
gem 'google_drive', '~> 2.1'

gem 'icalendar'

gem 'exception_notification'
gem 'exception_notification-rake'

gem 'faraday'
gem 'faraday-cookie_jar'

gem 'prawn'
gem 'prawn-table'
gem 'carrierwave'
gem 'carrierwave-postgresql'

gem 'postmark-rails'

group :production do
  gem 'rails_12factor'
  gem 'dalli'
end

group :development do
  gem 'rack-livereload'
  gem 'guard-livereload', require: false
  gem 'letter_opener'
  gem 'bullet'
end

group :development, :test do
  gem 'dotenv-rails'
  gem 'rspec-rails'
  gem 'spring-commands-rspec'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'pdf-inspector', require: 'pdf/inspector'
end

group :test do
  gem 'capybara'
  gem 'capybara-email'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
end

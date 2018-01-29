source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '2.4.3'

gem 'rails', '5.2.0.beta2'
gem 'bootsnap', require: false

gem 'rails-i18n'
gem 'puma'

gem 'rack-status'

gem 'pg', '~> 0.21'
gem 'uniquify'
gem 'paranoia'
gem 'phony_rails'
gem 'apartment'
gem 'apartment-activejob'

gem 'activeadmin'
gem 'activeadmin_medium_editor'
gem 'formadmin'
# Rails 5.2 support
gem 'polyamorous', github: 'spark-solutions/polyamorous'
gem 'ransack', github: 'spark-solutions/ransack'
gem 'cancancan'
gem 'devise'
gem 'devise-i18n'

gem 'turbolinks'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails'
gem 'highcharts-rails'
gem 'momentjs-rails'
gem 'slim'

gem 'uglifier'
gem 'jbuilder'
gem 'sass-rails'
gem 'font-awesome-sass'
gem 'bourbon', '~> 4.2.7'
gem 'bitters', '~> 1.2.0'
gem 'neat', '~> 1.8'
gem 'refills'

gem 'sucker_punch'

gem 'exception_notification'
gem 'exception_notification-rake'

gem 'faraday'
gem 'faraday-cookie_jar'

gem 'google_drive', '~> 2.1'
gem 'icalendar'
gem 'prawn'
gem 'prawn-table'
gem 'rubyXL'

group :production do
  gem 'redis'
  gem 'hiredis', require: false
  gem 'postmark-rails'
  gem 'aws-sdk-s3', require: false
end

group :development do
  gem 'listen'
  gem 'web-console'
  gem 'letter_opener'
  gem 'bullet'
end

group :development, :test do
  gem 'dotenv-rails'
  gem 'rspec-rails'
  gem 'capybara'
  gem 'spring-commands-rspec'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pdf-inspector', require: 'pdf/inspector'
end

group :test do
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
end

source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '2.5.1'

gem 'rails', '5.2.1'

gem 'bootsnap', require: false
gem 'pg'
gem 'puma'

gem 'i18n-backend-side_by_side'
gem 'rails-i18n'

gem 'rack-status'

gem 'apartment'
gem 'apartment-activejob'
gem 'paranoia'
gem 'phony_rails'

gem 'activeadmin'
gem 'cancancan'
gem 'devise'
gem 'devise-i18n'
gem 'formadmin'
gem 'ransack'

gem 'highcharts-rails'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails'
gem 'momentjs-rails'
gem 'slim'
gem 'turbolinks'

gem 'autoprefixer-rails'
gem 'font-awesome-sass'
gem 'jbuilder'
gem 'sass-rails'
gem 'uglifier'

gem 'sucker_punch'

gem 'exception_notification'
gem 'exception_notification-rake'
gem 'skylight'

gem 'faraday'
gem 'faraday-cookie_jar'

gem 'gibbon'
gem 'icalendar'
gem 'mini_magick'
gem 'postmark'
gem 'prawn'
gem 'prawn-table'
gem 'rubyXL'

group :production do
  gem 'aws-sdk-s3', require: false
  gem 'hiredis', require: false
  gem 'redis'
end

group :development do
  gem 'bullet'
  gem 'listen'
  gem 'rack-dev-mark'
  gem 'web-console'
end

group :development, :test do
  gem 'capybara'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pdf-inspector', require: 'pdf/inspector'
  gem 'rspec-rails'
  gem 'spring-commands-rspec'
end

group :test do
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
end

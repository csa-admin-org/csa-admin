ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.dirname(__FILE__) + '/../config/environment'
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'
require 'sucker_punch/testing/inline'

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
ActiveRecord::Migration.maintain_test_schema!
InvisibleCaptcha.timestamp_enabled = false

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) do
    FactoryBot.reload
    unless ACP.exists?(host: 'ragedevert')
      FactoryBot.create(:acp, host: 'ragedevert', tenant_name: 'ragedevert')
    end
  end

  config.around(:each) do |example|
    Apartment::Tenant.switch('ragedevert') do
      example.run
    end
    Current.reset
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
    Capybara.app_host = 'http://admin.ragedevert.test'
  end
end

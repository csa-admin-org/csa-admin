# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require "spec_helper"
require File.dirname(__FILE__) + "/../config/environment"
require "rspec/rails"
require "super_diff/rspec-rails"
require "capybara/rails"
require "capybara/rspec"
require "capybara/email/rspec"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!
Faker::Config.locale = :fr

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper

  config.before(:suite) do
    I18n.locale = :fr
    Tenant.switch("acme") do
      FactoryBot.create(:organization) unless Organization.exists?
    end
  end

  config.around(:example) do |example|
    Tenant.switch("acme") { example.run }
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
    Capybara.app_host = "http://admin.acme.test"
  end

  config.after(:each) do
    FactoryBot.rewind_sequences
    Faker::UniqueGenerator.clear
  end
end

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
    unless Tenant.schema_exists?("ragedevert")
      Tenant.create!("ragedevert") do
        FactoryBot.create(:organization)
      end
    end
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
    Capybara.app_host = "http://admin.ragedevert.test"
  end

  config.around(:each) do |example|
    Tenant.switch!("ragedevert")
    example.run
  ensure
    Tenant.reset
  end

  config.after(:each) do
    FactoryBot.rewind_sequences
    Faker::UniqueGenerator.clear
  end
end

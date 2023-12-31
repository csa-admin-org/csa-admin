ENV["RAILS_ENV"] ||= "test"
require "spec_helper"
require File.dirname(__FILE__) + "/../config/environment"
require "rspec/rails"
require "super_diff/rspec-rails"
require "capybara/rails"
require "capybara/rspec"
require "capybara/email/rspec"
require "sidekiq/testing"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
ActiveRecord::Migration.maintain_test_schema!
ActiveJob::Uniqueness.test_mode!

Faker::Config.locale = :fr

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) do
    unless ACP.exists?(host: "ragedevert")
      FactoryBot.create(:acp, host: "ragedevert", tenant_name: "ragedevert")
    end
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
    Capybara.app_host = "http://admin.ragedevert.test"
  end

  config.around(:each) do |example|
    Tenant.switch("ragedevert") do
      example.run
    end
  end

  config.after(:each) do
    FactoryBot.rewind_sequences
    Current.reset!
    Faker::UniqueGenerator.clear
  end

  shared_context "sidekiq:inline", sidekiq: :inline do
    around(:each) { |ex| Sidekiq::Testing.inline!(&ex) }
  end
end

ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.dirname(__FILE__) + '/../config/environment'
require 'rspec/rails'
require 'capybara/email/rspec'
require 'sucker_punch/testing/inline'

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    Delivery.create_all(Date.new(Time.zone.today.year - 1, 1, 14))
    Delivery.create_all(Date.new(Time.zone.today.year, 1, 14))
  end
  config.after(:suite) do
    Delivery.delete_all
  end
end

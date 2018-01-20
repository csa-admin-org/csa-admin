ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.dirname(__FILE__) + '/../config/environment'
require 'rspec/rails'
require 'sucker_punch/testing/inline'

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.reload
    unless ACP.exists?(host: 'ragedevert')
      FactoryBot.create(:acp, host: 'ragedevert', tenant_name: 'ragedevert')
    end
    Apartment::Tenant.switch('ragedevert') do
      Delivery.create_all(40, Date.new(Time.zone.today.year - 1, 1, 14))
      Delivery.create_all(40, Date.new(Time.zone.today.year, 1, 14))
    end
  end

  config.after(:suite) do
    Apartment::Tenant.switch('ragedevert') do
      Delivery.delete_all
    end
  end

  config.around(:each) do |example|
    Rails.cache.clear
    Apartment::Tenant.switch('ragedevert') do
      example.run
    end
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
  end
end

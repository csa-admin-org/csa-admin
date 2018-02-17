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
      Delivery.delete_all
      date = Current.fiscal_year.beginning_of_year + 2.weeks
      Delivery.create_all(40, date - 1.year)
      Delivery.create_all(40, date)
    end
  end

  config.around(:each) do |example|
    Rails.cache.clear
    Apartment::Tenant.switch('ragedevert') do
      CurrentACP.set_acp_logo('rdv_logo.jpg')
      example.run
    end
    Current.reset
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
  end
end

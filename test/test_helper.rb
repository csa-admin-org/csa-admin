# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require "capybara/email"

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

Minitest::Test.make_my_diffs_pretty!

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper
    include Capybara::Email::DSL
    include Assertions

    include AbsencesHelper
    include ActivitiesHelper
    include BasketComplementsHelper
    include BasketContentsHelper
    include BasketSizesHelper
    include BillingHelper
    include DeliveryCyclesHelper
    include DepotsHelper
    include EmailSuppressionsHelper
    include InvoicesHelper
    include MailTemplatesHelper
    include MembersHelper
    include MembershipsHelper
    include NewslettersHelper
    include OrganizationsHelper
    include PaymentsHelper
    include PostmarkHelper
    include ResponsesHelper
    include SessionsHelper
    include ShopHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      Tenant.connect("acme")
      skip_invoice_pdf
    end

    teardown do
      Tenant.disconnect
      clear_emails
      I18n.locale = I18n.default_locale
    end
  end
end

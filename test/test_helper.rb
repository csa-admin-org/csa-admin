# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["CAP_SKIP_VERIFY"] ||= "1"
# bin/dev and worktree mise.local.toml set these; tests that need them set them.
ENV.delete("DEV_ORIGIN")
ENV.delete("TENANT")
require_relative "../config/environment"
require "rails/test_help"

require "capybara/email"
require "webmock/minitest"
require "minitest/mock"

# Disable all real HTTP connections in tests (WebMock will raise on any attempt)
WebMock.disable_net_connect!

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

Minitest.load_plugins
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
    include QRCodeHelper
    include EnvHelper
    include EbicsKeyStoreHelper
    include EbicsSchemaHelper
    include RailsEnvHelper
    include RailsErrorHelper
    include TenantHelper
    include ResponsesHelper
    include SessionsHelper
    include CapTestHelper
    include ShopHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      TestHotCellServer.start(worker: worker)
    end

    parallelize_teardown do
      TestHotCellServer.stop
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      TestHotCellServer.ensure_started!
      Tenant.connect("acme")
      skip_invoice_pdf
      skip_sepa_mandate_pdf
    end

    teardown do
      Tenant.disconnect
      clear_emails
      I18n.locale = I18n.default_locale
    end
  end
end

# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require 'capybara/email'

require "support/activities_helper"
require "support/deliveries_helper"
require "support/email_suppressions_helper"
require "support/invoices_helper"
require "support/organizations_helper"
require "support/mail_templates_helper"
require "support/members_helper"
require "support/memberships_helper"
require "support/payments_helper"
require "support/postmark_helper"
require "support/responses_helper"
require "support/sessions_helper"

Minitest::Test.make_my_diffs_pretty!

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper
    include Capybara::Email::DSL

    include ActivitiesHelper
    include DeliveriesHelper
    include EmailSuppressionsHelper
    include InvoicesHelper
    include MailTemplatesHelper
    include MembersHelper
    include MembershipsHelper
    include OrganizationsHelper
    include PaymentsHelper
    include PostmarkHelper
    include ResponsesHelper
    include SessionsHelper

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
    end
  end
end

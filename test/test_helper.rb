# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require "support/activities_helper"
require "support/mail_templates_helper"
require "support/responses_helper"
require "support/sessions_helper"

Minitest::Test.make_my_diffs_pretty!

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    include ActivitiesHelper
    include SessionsHelper
    include MailTemplatesHelper
    include ResponsesHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      Tenant.connect("acme")
    end

    teardown do
      Tenant.disconnect
    end
  end
end

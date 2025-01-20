# frozen_string_literal: true

require "test_helper"

require "support/flash_messages_helper"
require "support/ui_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  include FlashMessagesHelper
  include UIHelper

  driven_by :rack_test

  setup do |test|
    subdomain = test.class.name.include?("Members::") ? "members" : "admin"
    Capybara.app_host = "http://#{subdomain}.acme.test"
  end
end

# frozen_string_literal: true

require "test_helper"
require "rake"

class OrganizationsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("organizations:next_fiscal_year")
    Rake::Task["organizations:next_fiscal_year"].reenable
    Rake::Task["organizations:encrypt_tokens"].reenable if Rake::Task.task_defined?("organizations:encrypt_tokens")
  end

  test "lists organizations grouped by next fiscal year start" do
    date = Current.org.next_fiscal_year.range.min
    Tenant.disconnect

    out, = capture_io { Rake::Task["organizations:next_fiscal_year"].invoke }

    assert_includes out, "-- #{date} --"
    assert_includes out, "Acme"
  ensure
    Tenant.connect("acme")
  end

  test "encrypt_tokens writes ciphertext for fixture tokens" do
    Tenant.disconnect
    with_env("CONFIRM" => "true", "TENANT" => "acme") do
      out, = capture_io { Rake::Task["organizations:encrypt_tokens"].invoke }
      assert_includes out, "acme: encrypted"
    end
  ensure
    Tenant.connect("acme")
    Current.reset
    org = Current.org.reload
    assert_equal "1234abcd", org.api_token
    assert org.encrypted_attribute?(:api_token)
    assert org.encrypted_attribute?(:icalendar_auth_token)
  end

  test "encrypt_tokens requires CONFIRM" do
    error = assert_raises(SystemExit) {
      capture_io { Rake::Task["organizations:encrypt_tokens"].invoke }
    }
    assert_equal 1, error.status
  end
end

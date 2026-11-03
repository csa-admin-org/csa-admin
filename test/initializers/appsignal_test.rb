# frozen_string_literal: true

require "test_helper"

class AppsignalTest < ActiveSupport::TestCase
  test "does not send session data or job arguments" do
    config = Appsignal.config

    refute config[:send_session_data]
    refute config[:send_function_parameters]
  end

  test "request samples omit path headers that can carry tokens" do
    headers = Appsignal.config[:request_headers]

    assert_not_includes headers, "PATH_INFO"
    assert_not_includes headers, "REQUEST_PATH"
    assert_includes headers, "REQUEST_METHOD"
  end

  test "filters personal data keys with an exact match" do
    keys = Appsignal.config[:filter_parameters]

    assert_includes keys, "iban"
    assert_includes keys, "From"
    assert_includes keys, "HtmlBody"
  end
end

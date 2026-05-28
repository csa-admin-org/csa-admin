# frozen_string_literal: true

require "test_helper"
require "rack/test"

class Rack::CatchBadMultipartTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::CatchBadMultipart
      use Rack::MethodOverride
      run ->(env) { [ 200, { "content-type" => "text/plain" }, [ "OK" ] ] }
    end
  end

  test "returns 400 for multipart boundary too long" do
    boundary = "x" * 71
    body = "--#{boundary}\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--#{boundary}--\r\n"

    header "content-type", "multipart/form-data; boundary=#{boundary}"
    post "/", body

    assert_equal 400, last_response.status
    assert_equal "Bad Request", last_response.body
  end

  test "passes through normal requests" do
    post "/"

    assert_equal 200, last_response.status
  end
end

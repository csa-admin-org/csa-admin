# frozen_string_literal: true

module ResponsesHelper
  def json_response
    JSON.parse(response.body)
  end

  def assert_no_store_download_headers
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
    assert_equal "0", response.headers["Expires"]
  end
end

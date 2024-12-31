# frozen_string_literal: true

module ResponsesHelper
  def json_response
    JSON.parse(response.body)
  end
end

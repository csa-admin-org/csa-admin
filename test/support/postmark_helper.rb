# frozen_string_literal: true

require_relative "./postmark_mock_client"

module PostmarkHelper
  def postmark_client
    PostmarkMockClient.instance
  end
end

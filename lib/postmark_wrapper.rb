# frozen_string_literal: true

class PostmarkWrapper
  def self.client
    if Rails.env.production?
      Postmark::ApiClient.new(Current.org.postmark_server_token)
    else
      require Rails.root + "test/support/postmark_mock_client"
      PostmarkMockClient.instance
    end
  end

  def self.method_missing(message, *args, &block)
    client.send(message, *args, &block)
  end
end

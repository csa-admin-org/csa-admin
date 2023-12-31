class PostmarkWrapper
  def self.client
    if Rails.env.production?
      server_token = Current.acp.credentials(:postmark, :api_token)
      Postmark::ApiClient.new(server_token)
    else
      require Rails.root + "spec/support/postmark_mock_client"
      PostmarkMockClient.instance
    end
  end

  def self.method_missing(message, *args, &block)
    client.send(message, *args, &block)
  end
end

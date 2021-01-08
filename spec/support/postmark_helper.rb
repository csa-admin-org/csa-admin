module PostmarkHelper
  def postmark_client
    PostmarkMockClient.instance
  end
end

RSpec.configure do |config|
  config.include(PostmarkHelper)
  config.after(:each) { postmark_client.reset! }
end

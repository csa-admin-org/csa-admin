module EmailHelper
  def email_adapter
    Email::MockAdapter.instance
  end
end

RSpec.configure do |config|
  config.include(EmailHelper)
  config.after(:each) { Email::MockAdapter.reset! }
end

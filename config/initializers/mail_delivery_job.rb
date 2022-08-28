require 'current_context'

module ActionMailer
  class MailDeliveryJob < ActiveJob::Base
    include CurrentContext
  end
end

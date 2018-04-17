class Email::DeliverJob < ApplicationJob
  queue_as :default

  def perform(template, *args)
    Email.deliver_now(template, *args)
  end
end

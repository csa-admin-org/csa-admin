require 'email'

module Email
  class MockAdapter
    include Singleton

    class_attribute :deliveries

    def deliver(from:, to:, template:, template_data:, attachments: [])
      deliveries << {
        from: from,
        to: to,
        template: template,
        template_data: template_data,
        attachments: attachments
      }
      Rails.logger.info "Email delivered:\n#{deliveries.last.inspect}"
      true
    end

    def self.reset!
      self.deliveries = []
    end
    reset!
  end
end

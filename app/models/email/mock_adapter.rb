require 'email'

module Email
  class MockAdapter
    include Singleton

    attr_reader :deliveries

    def initialize
      reset!
    end

    def deliver(from:, to:, template:, template_data:, attachments: [])
      @deliveries << {
        from: from,
        to: to,
        template: template,
        template_data: template_data,
        attachments: attachments
      }
      Rails.logger.info "Email delivered:\n#{deliveries.last.inspect}"
      true
    end

    def reset!
      @deliveries = []
    end
  end
end

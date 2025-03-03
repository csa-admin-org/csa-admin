# frozen_string_literal: true

unless Rails.env.local?
  appsignal_logger = Appsignal::Logger.new("rails")
  appsignal_logger.broadcast_to(Rails.logger)
  Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
end

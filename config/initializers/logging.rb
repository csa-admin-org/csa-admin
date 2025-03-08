# frozen_string_literal: true

if Rails.env.production?
  appsignal_logger = Appsignal::Logger.new("rails")
  appsignal_logger.broadcast_to(Rails.logger)
  Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
end

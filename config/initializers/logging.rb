# frozen_string_literal: true

appsignal_logger = Appsignal::Logger.new("rails")
appsignal_logger.broadcast_to(Rails.logger)
Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)

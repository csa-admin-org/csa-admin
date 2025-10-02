# frozen_string_literal: true

if Rails.env.production?
  appsignal_logger = Appsignal::Logger.new("rails")
  appsignal_logger.broadcast_to(Rails.logger)
  Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
end

class LogSubscriber
  def emit(event)
    payload = {}
    payload.merge!(event[:payload] || {})
    payload.merge!(event[:tags] || {})
    payload.merge!(event[:context] || {})
    payload = payload.map { |key, value| "#{key}=#{value}" }.join(" ")
    Rails.logger.info("event=#{event[:name]} #{payload}")
  end
end

Rails.event.subscribe(LogSubscriber.new)

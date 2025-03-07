# frozen_string_literal: true

module SLog
  def self.log(event, context = {})
    context = {
      event: event.to_s,
      org: Tenant.current
    }.merge(context)
    filtered_context = filter_parameters(context)

    Rails.logger.info filtered_context.map { |k, v| "#{k}=#{v.inspect}" }.join(" ")
  end

  def self.filter_parameters(params)
    @filterer ||= ActiveSupport::ParameterFilter.new(
      Rails.application.config.filter_parameters)
    @filterer.filter(params)
  end
end

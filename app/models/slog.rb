# frozen_string_literal: true

module SLog
  def self.log(event, context = {})
    context[:org] = Tenant.current
    Rails.logger.info { "#{event} #{context.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')}" }
  end
end

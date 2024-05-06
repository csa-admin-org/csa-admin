module SLog
  def self.log(event, context = {})
    context[:acp] = Tenant.current
    Rails.logger.info "#{event} #{context.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')}"
  end
end

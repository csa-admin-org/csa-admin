module SLog
  def self.log(event, context = {})
    Rails.logger.info "#{event} #{context.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')}"
  end
end

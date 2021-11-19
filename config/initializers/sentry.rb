Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger]
  config.traces_sample_rate = ENV['SENTRY_TRACES_SAMPLE_RATE']&.to_f || 0.1
end

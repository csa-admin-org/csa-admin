module ExceptionNotifier
  def self.notify(ex, data = {})
    options = { data: data }
    options[:data][:acp] ||= Current.acp&.name
    notify_exception(ex, options)
  end
end

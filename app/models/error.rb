# frozen_string_literal: true

module Error
  extend self

  class NotificationError < StandardError; end

  def notify(message, **extra)
    report(NotificationError.new(message), **extra)
  end

  def report(error, **extra)
    Appsignal.report_error(error) do
      Appsignal.add_tags(extra)
    end
  end
end

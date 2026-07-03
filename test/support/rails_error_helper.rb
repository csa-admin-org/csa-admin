# frozen_string_literal: true

module RailsErrorHelper
  def with_rails_error(error)
    original = Rails.method(:error)
    Rails.define_singleton_method(:error) { error }
    yield
  ensure
    Rails.define_singleton_method(:error, original)
  end

  class ErrorRecorder
    attr_reader :reports, :unexpected_errors

    def initialize
      @reports = []
      @unexpected_errors = []
    end

    def report(error, context: {}, **options)
      reports << [ error, context, options ]
    end

    def unexpected(error, context: {})
      unexpected_errors << [ error, context ]
    end
  end
end

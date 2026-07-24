# frozen_string_literal: true

module Security
  class Reporter
    def initialize(result, output: $stdout)
      @result = result
      @output = output
    end

    def call
      result.outcomes.each { |outcome| report(outcome) }
    end

    private

    attr_reader :result, :output

    def report(outcome)
      outcome.success? ? report_success(outcome) : report_failure(outcome)
    end

    def report_success(outcome)
      output.puts "✅ #{outcome.name}"
    end

    def report_failure(outcome)
      output.puts "❌ #{outcome.name}"
      output.puts outcome.output.rstrip unless outcome.output.empty?
      output.puts
    end
  end
end

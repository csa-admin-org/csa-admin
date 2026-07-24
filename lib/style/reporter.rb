# frozen_string_literal: true

module Style
  class Reporter
    def initialize(result, output: $stdout)
      @result = result
      @output = output
    end

    def call
      return report_unmatched if result.unmatched?

      result.outcomes.each { |outcome| report(outcome) }
    end

    private

    attr_reader :result, :output

    def report_unmatched
      output.puts "No style tools matched: #{result.paths.join(", ")}"
    end

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

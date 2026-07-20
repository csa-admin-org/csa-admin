# frozen_string_literal: true

require "open3"
require "parallel"

module Lint
  class Runner
    def initialize(mode:, paths:, executor: nil, mapper: Parallel.method(:map))
      @mode = mode
      @paths = paths
      @executor = executor || method(:execute)
      @mapper = mapper
    end

    def call
      report_all
      abort("Linting failed") if failures?
    end

    private

    def report_all
      outcomes.each { |outcome| report(outcome) }
    end

    def failures?
      outcomes.any? { |outcome| !outcome.success? }
    end

    def outcomes
      @outcomes ||= results.compact.sort_by(&:finished_at)
    end

    def results
      @mapper.call(Linters.all) { |linter| run(linter) }
    end

    def run(linter_class)
      linter = linter_class.new(@paths)
      command = linter.command(@mode)
      return if command.blank?

      output, success = @executor.call(command)
      Outcome.from(name: linter.name, success:, output:)
    end

    def execute(command)
      output, status = Open3.capture2e(command)
      [ output, status.success? ]
    end

    def report(outcome)
      if outcome.success?
        puts "✅ #{outcome.name}"
      else
        puts "❌ #{outcome.name}"
        puts outcome.output.rstrip unless outcome.output.blank?
        puts
      end
    end
  end
end

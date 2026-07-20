# frozen_string_literal: true

require "open3"
require "parallel"

module Style
  class Runner
    def initialize(mode:, paths:, executor: nil, mapper: Parallel.method(:map))
      @mode = mode
      @paths = paths
      @executor = executor || method(:execute)
      @mapper = mapper
    end

    def call
      report_all
      abort(failure_message) if failures?
    end

    private

    def report_all
      outcomes.each { |outcome| report(outcome) }
    end

    def failures?
      outcomes.any? { |outcome| !outcome.success? }
    end

    def failure_message
      names = outcomes.reject(&:success?).map(&:name).join(", ")
      "Style #{@mode} failed: #{names}"
    end

    def outcomes
      @outcomes ||= results.compact.sort_by(&:finished_at)
    end

    def results
      @mapper.call(Tools.all) { |tool| run(tool) }
    end

    def run(tool_class)
      tool = tool_class.new(@paths)
      command = tool.command(@mode)
      return if command.blank?

      output, success = @executor.call(command)
      Outcome.from(name: tool.name, success:, output:)
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

# frozen_string_literal: true

require "open3"
require "parallel"

module Security
  class Runner
    MAX_THREADS = 3

    def initialize(root:, executor: nil, mapper: nil)
      @root = File.expand_path(root)
      @executor = executor || method(:execute)
      @mapper = mapper || method(:map)
    end

    def call
      Result.new(outcomes: outcomes)
    end

    private

    def outcomes
      @mapper.call(Tools.all) { |tool| run(tool) }.compact
    end

    def run(tool_class)
      tool = tool_class.new
      command = tool.command
      return if command.nil? || command.empty?

      execute_tool(tool, command)
    end

    def execute_tool(tool, command)
      output, success = @executor.call(command)
      Outcome.from(name: tool.name, success:, output:)
    rescue SystemCallError => error
      Outcome.from(name: tool.name, success: false, output: "#{error.class}: #{error.message}")
    end

    def map(tools, &block)
      Parallel.map(tools, in_threads: MAX_THREADS, &block)
    end

    def execute(command)
      output, status = Open3.capture2e(*command, chdir: @root)
      [ output, status.success? ]
    end
  end
end

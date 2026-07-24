# frozen_string_literal: true

require "open3"
require "parallel"

module Style
  class Runner
    MODES = %i[check fix].freeze
    MAX_THREADS = 3

    def initialize(mode:, paths:, root:, executor: nil, mapper: nil)
      validate_mode!(mode)
      @mode = mode
      @root = File.expand_path(root)
      @paths = Paths.normalize(paths, root: @root)
      @executor = executor || method(:execute)
      @mapper = mapper || method(:map)
    end

    def call
      Result.new(mode: @mode, paths: @paths, outcomes: outcomes)
    end

    private

    def outcomes
      Tools.phases(@mode).flat_map { |phase| run_phase(phase) }
    end

    def run_phase(phase)
      @mapper.call(phase.tools) { |tool| run(tool, phase.mode) }.compact
    end

    def run(tool_class, mode)
      tool = tool_class.new(@paths, root: @root)
      command = tool.command(mode)
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
      Parallel.map(tools, in_threads: [ MAX_THREADS, tools.size ].min, &block)
    end

    def execute(command)
      output, status = Open3.capture2e(*command, chdir: @root)
      [ output, status.success? ]
    end

    def validate_mode!(mode)
      fail ArgumentError, "invalid style mode: #{mode.inspect}" unless MODES.include?(mode)
    end
  end
end

# frozen_string_literal: true

require "style/paths"
require "style/path_selector"
require "style/tool"
require "style/tools"
require "style/outcome"
require "style/result"
require "style/runner"
require "style/reporter"

module Style
  ROOT = File.expand_path("..", __dir__)

  module_function

  def run(mode, paths: [])
    Runner.new(mode:, paths:, root: ROOT).call
  end

  def run!(mode, paths: [])
    run(mode, paths:).tap do |result|
      Reporter.new(result).call
      abort(result.failure_message) if result.failure?
    end
  rescue Paths::OutsideRootError => error
    abort "Style #{mode} failed: #{error.message}"
  end
end

# frozen_string_literal: true

require "security/tools"
require "security/outcome"
require "security/result"
require "security/runner"
require "security/reporter"

module Security
  ROOT = File.expand_path("..", __dir__)

  module_function

  def run
    Runner.new(root: ROOT).call
  end

  def run!
    run.tap do |result|
      Reporter.new(result).call
      abort(result.failure_message) if result.failure?
    end
  end
end

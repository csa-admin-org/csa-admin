# frozen_string_literal: true

require "lint/path_selector"
require "lint/linter"
require "lint/linters"
require "lint/outcome"
require "lint/runner"

module Lint
  TASK_NAMES = %w[lint:check lint:autocorrect lint].freeze

  module_function

  # Rails rejects unknown top-level tasks, so register path args as no-ops.
  # Must run at rake load time, outside `namespace :lint`.
  def register_path_arguments!
    return unless invoked?

    path_arguments.each { |name| define_noop_task(name) }
  end

  def run(mode)
    Runner.new(mode:, paths: path_arguments).call
  end

  def path_arguments
    Rake.application.top_level_tasks - TASK_NAMES - %w[default]
  end

  def invoked?
    (Rake.application.top_level_tasks & TASK_NAMES).any?
  end

  def define_noop_task(name)
    base = name[/[^\[]+/]
    Rake::Task.define_task(name) unless Rake.application.lookup(base)
  end

  private_class_method :invoked?, :define_noop_task
end

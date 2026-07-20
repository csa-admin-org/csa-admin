# frozen_string_literal: true

require "shellwords"

module Lint
  class Linter
    def initialize(paths)
      @paths = paths
    end

    def name
      self.class.name.demodulize.underscore.to_sym
    end

    def command(mode)
      raise NotImplementedError
    end

    private

    attr_reader :paths

    def select(patterns: [], prefixes: [])
      PathSelector.call(paths, patterns:, prefixes:)
    end

    def join(selected)
      Shellwords.join(selected)
    end

    def skip?(selected)
      paths.any? && selected.empty?
    end

    def check?(mode)
      mode == :check
    end
  end
end

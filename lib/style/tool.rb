# frozen_string_literal: true

require "shellwords"

module Style
  class Tool
    def initialize(paths)
      @paths = paths
    end

    def name
      self.class.name
        .split("::").last
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .downcase
        .to_sym
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

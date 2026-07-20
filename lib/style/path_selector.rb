# frozen_string_literal: true

module Style
  module PathSelector
    FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

    module_function

    def call(paths, patterns: [], prefixes: [])
      paths.select { |path| match?(path, patterns, prefixes) }
    end

    def match?(path, patterns, prefixes)
      pattern_match?(path, patterns) || prefix_match?(path, prefixes)
    end

    def pattern_match?(path, patterns)
      patterns.any? { |pattern| File.fnmatch?(pattern, path, FLAGS) }
    end

    def prefix_match?(path, prefixes)
      prefixes.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
    end
  end
end

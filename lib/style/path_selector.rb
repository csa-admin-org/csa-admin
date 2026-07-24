# frozen_string_literal: true

module Style
  module PathSelector
    FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

    module_function

    def call(paths, patterns: [], prefixes: [], root: Dir.pwd)
      root = File.expand_path(root)

      paths.filter_map { |path| select(path, patterns:, prefixes:, root:) }.uniq
    end

    def select(path, patterns:, prefixes:, root:)
      prefix = prefix_for(path, prefixes, root:)
      return prefix if prefix && prefix != path
      path if prefix || pattern_match?(path, patterns, root:)
    end

    def prefix_for(path, prefixes, root:)
      prefixes.each { |prefix| return path if inside_prefix?(path, prefix) }
      prefixes.each { |prefix| return prefix if ancestor_directory?(path, prefix, root:) }

      nil
    end

    def pattern_match?(path, patterns, root:)
      return true if match?(path, patterns)

      directory_contains_match?(path, patterns, root:)
    end

    def directory_contains_match?(path, patterns, root:)
      directory = File.expand_path(path, root)
      return false unless File.directory?(directory)

      patterns.any? { |pattern| directory_pattern_match?(path, pattern, root:) }
    end

    def directory_pattern_match?(path, pattern, root:)
      return Dir.glob(pattern, base: File.expand_path(path, root)).any? if pattern.start_with?("**/")

      Dir.glob(pattern, base: root).any? { |entry| inside_directory?(entry, path) }
    end

    def inside_directory?(entry, directory)
      directory == "." || entry == directory || entry.start_with?("#{directory}/")
    end

    def inside_prefix?(path, prefix)
      path == prefix || path.start_with?("#{prefix}/")
    end

    def ancestor_directory?(path, prefix, root:)
      directory?(path, root:) && (path == "." || prefix.start_with?("#{path}/"))
    end

    def directory?(path, root:)
      File.directory?(File.expand_path(path, root))
    end

    def match?(path, patterns)
      patterns.any? { |pattern| File.fnmatch?(pattern, path, FLAGS) }
    end
    private_class_method :select, :prefix_for, :pattern_match?, :directory_contains_match?,
      :directory_pattern_match?, :inside_directory?, :inside_prefix?, :ancestor_directory?, :directory?, :match?
  end
end

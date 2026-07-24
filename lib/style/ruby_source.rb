# frozen_string_literal: true

module Style
  module RubySource
    BASENAMES = %w[Gemfile Rakefile].freeze
    EXTENSIONS = %w[.arb .gemspec .rake .rb .ru .ruby].freeze
    RUBY_SHEBANG = /\A#!.*(?:\/|\s)ruby(?:\s|$)/n

    module_function

    def select(paths, root:)
      paths.select { |path| source?(path, root:) }
    end

    def source?(path, root:)
      absolute_path = File.expand_path(path, root)
      return directory_contains_source?(absolute_path) if File.directory?(absolute_path)

      known_name?(path) || File.extname(path).empty? && ruby_shebang?(absolute_path)
    end

    def known_name?(path)
      BASENAMES.include?(File.basename(path)) || EXTENSIONS.include?(File.extname(path))
    end

    def directory_contains_source?(directory)
      Dir.glob("**/*", base: directory).any? { |path|
        absolute_path = File.join(directory, path)
        File.file?(absolute_path) && source?(absolute_path, root: directory)
      }
    end

    def ruby_shebang?(path)
      File.file?(path) && File.binread(path, 256)&.match?(RUBY_SHEBANG) || false
    end
    private_class_method :directory_contains_source?, :ruby_shebang?
  end
end

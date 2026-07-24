# frozen_string_literal: true

module Style
  module Paths
    OutsideRootError = Class.new(ArgumentError)

    module_function

    def normalize(paths, root:)
      root = File.expand_path(root)
      real_root = File.realpath(root)

      paths.map { |path| normalize_path(path, root:, real_root:) }.uniq
    end

    def normalize_path(path, root:, real_root:)
      absolute_path = File.expand_path(path, root)
      reject_outside_root!(path) unless inside_root?(absolute_path, root)
      reject_outside_root!(path) unless inside_root?(resolved_ancestor(absolute_path), real_root)

      absolute_path == root ? "." : absolute_path.delete_prefix("#{root}/")
    end

    def resolved_ancestor(path)
      path = File.dirname(path) until File.exist?(path) || File.symlink?(path)
      File.realpath(path)
    rescue Errno::ENOENT
      nil
    end

    def inside_root?(path, root)
      path && (path == root || path.start_with?("#{root}/"))
    end

    def reject_outside_root!(path)
      raise OutsideRootError, "path outside repository: #{path}"
    end
    private_class_method :normalize_path, :resolved_ancestor, :inside_root?, :reject_outside_root!
  end
end

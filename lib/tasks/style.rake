# frozen_string_literal: true

require "style"

Style.register_path_arguments!

namespace :style do
  desc "Run all style tools to check code (no fixes). Optional paths: bin/rails style:check path [path...]"
  task :check do
    Style.run(:check)
  end

  desc "Run all style tools with auto-fix/format. Optional paths: bin/rails style:fix path [path...]"
  task :fix do
    Style.run(:fix)
  end
end

# Alias bin/rails style to style:check
task style: "style:check"

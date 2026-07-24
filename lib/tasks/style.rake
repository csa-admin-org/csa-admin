# frozen_string_literal: true

require "style"

namespace :style do
  desc "Run all style tools to check code (no fixes)"
  task :check do
    Style.run!(:check)
  end

  desc "Run all style tools with auto-fix/format"
  task :fix do
    Style.run!(:fix)
  end
end

# Alias bin/rails style to style:check
task style: "style:check"

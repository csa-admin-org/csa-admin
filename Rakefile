# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path("../config/application", __FILE__)

Rails.application.load_tasks

# Conditionally skip Tailwind build in test:prepare if SKIP_TAILWINDCSS_BUILD is set
if ENV["SKIP_TAILWINDCSS_BUILD"]
  task = Rake::Task["test:prepare"]
  task.prerequisites.delete("tailwindcss:build") if task.prerequisites.include?("tailwindcss:build")
end

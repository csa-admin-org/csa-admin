# frozen_string_literal: true

namespace :development do
  task :restart do
    `touch tmp/restart.txt`
  end

  task :restore do
    Rake::Task["litestream:restore"].invoke
    Rake::Task["storage:restore"].invoke
    Rake::Task["development:restart"].invoke
  end

  namespace :restore do
    task :masked do
      Rake::Task["development:restore"].invoke
      Rake::Task["masker:run"].invoke
      Rake::Task["search:reindex"].invoke
    end
  end
end

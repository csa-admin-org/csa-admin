# frozen_string_literal: true

namespace :development do
  task :restart do
    `touch tmp/restart.txt`
  end

  desc "Restore local DB + storage from backups (optional TENANT=name1,name2)"
  task :restore do
    Rake::Task["litestream:restore"].invoke
    Rake::Task["storage:restore"].invoke
    Rake::Task["development:restart"].invoke
  end

  namespace :restore do
    desc "Restore then mask private data (optional TENANT=name1,name2)"
    task :masked do
      Rake::Task["development:restore"].invoke
      Rake::Task["masker:run"].invoke
      Rake::Task["search:reindex"].invoke
    end
  end
end

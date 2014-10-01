require 'importer'

namespace :spreadsheet do
  desc 'Import ordinary members'
  task import_members: :environment do
    Member.delete_all
    Importer.import('membres-14-08-29', 1..-4)
    p "#{Member.count} members imported."
  end
end

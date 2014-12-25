require 'importer'

namespace :spreadsheet do
  desc 'Import ordinary members'
  task import_members: :environment do
    Member.delete_all
    Membership.delete_all
    Importer.import('Membres', 1..-1)
    p "#{Member.count} members imported."
  end
end

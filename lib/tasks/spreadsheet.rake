namespace :spreadsheet do
  desc 'Import ordinary members'
  task import_members: :environment do
    Importer.import('Membres', 1..-1)
    p "#{Member.count} members imported."
  end

  desc 'Import new inscriptions'
  task import_new_inscriptions: :environment do
    InscriptionsImporter.import
    p "New inscriptions imported."
  end

  desc 'Import support members'
  task import_support_members: :environment do
    Member.support.delete_all
    SupportImporter.import('Membres Soutien', 1..-1)
    p "#{Member.support.count} support members imported."
  end
end

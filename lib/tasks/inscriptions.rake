namespace :inscriptions do
  desc 'Import inscriptions from google spreasheet (SquareSpace)'
  task import: :environment do
    Inscription.import
    p 'New inscriptions imported.'
  end
end

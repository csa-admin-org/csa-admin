namespace :inscriptions do
  desc 'Import inscriptions from google spreasheet (SquareSpace)'
  task import: :environment do
    ACP.enter!('ragedevert')
    Inscription.import
    p 'New inscriptions imported.'
  end
end

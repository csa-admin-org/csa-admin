namespace :inscriptions do
  desc 'Import new member inscriptions'
  task import: :environment do
    ACP.enter_each! do
      if worksheet_url = Current.acp.credentials(:inscriptions_worksheet_url)
        Inscription.import_from_google_sheet(worksheet_url)
        puts 'New inscriptions from Google Spreadsheet imported.'
      end
    end
  end
end

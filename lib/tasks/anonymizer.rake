namespace :anonymizer do
  desc 'Anonymize all private data (dev only)'
  task run: :environment do
    raise 'Dev only!' unless Rails.env.development?

    ACP.perform_each do
      Faker::Config.locale = Current.acp.default_locale
      Member.find_each do |member|
        member.update_columns(
          name: Faker::Name.unique.name,
          emails: Faker::Internet.unique.email,
          phones: Faker::Base.unique.numerify('+41 ## ### ## ##'),
          address: Faker::Address.street_address,
          city: Faker::Address.city,
          zip: Faker::Address.zip,
          delivery_address: nil,
          delivery_city: nil,
          delivery_zip: nil,
          note: nil,
          food_note: nil,
          come_from: nil,
          profession: nil)
        member.sessions.update_all(email: member.emails_array.first)
      end
      Admin.find_each do |admin|
        unless admin.email.in?([ENV['AUTO_SIGN_IN_ADMIN_EMAIL'], ENV['MASTER_ADMIN_EMAIL']])
          admin.update_columns(
            name: Faker::Name.unique.first_name,
            email: Faker::Internet.unique.email)
        end
      end
      Depot.find_each do |depot|
        if depot.emails?
          depot.update_columns(emails: Faker::Internet.unique.email)
        end
      end

      Faker::UniqueGenerator.clear
    end
  end
end

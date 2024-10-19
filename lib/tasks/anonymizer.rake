# frozen_string_literal: true

namespace :anonymizer do
  desc "Anonymize all private data (dev only)"
  task run: :environment do
    raise "Dev only!" unless Rails.env.development?

    Tenant.switch_each do
      Faker::Config.locale = Current.org.default_locale
      emails_mapping = {}
      Member.find_each do |member|
        fake_emails = member.emails_array.map do |email|
          fake_email = Faker::Internet.unique.email.downcase
          emails_mapping[email.downcase] = fake_email
          fake_email
        end
        member.update_columns(
          name: Faker::Name.unique.name,
          emails: fake_emails.join(", "),
          phones: Faker::Base.unique.numerify("+41 ## ### ## ##"),
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
      Newsletter::Delivery.where.not(email: nil).find_each do |delivery|
        delivery.update_columns(
          email: emails_mapping[delivery.email.downcase] || Faker::Internet.unique.email.downcase)
      end
      EmailSuppression.find_each do |suppression|
        suppression.update_column(
          :email,
          emails_mapping[suppression.email.downcase] || Faker::Internet.unique.email.downcase)
      end
      Admin.find_each do |admin|
        unless admin.email.in?([ ENV["AUTO_SIGN_IN_ADMIN_EMAIL"], ENV["MASTER_ADMIN_EMAIL"] ])
          admin.update_columns(
            name: Faker::Name.unique.first_name,
            email: Faker::Internet.unique.email)
        end
      end
      Depot.find_each do |depot|
        attrs = {}
        attrs[:emails] = Faker::Internet.unique.email if depot.emails?
        attrs[:contact_name] = Faker::Name.unique.name if depot.contact_name?
        depot.update_columns(attrs) if attrs.present?
      end

      Faker::UniqueGenerator.clear
    end
  end
end

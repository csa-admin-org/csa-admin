# frozen_string_literal: true

require "parallel"
require "faker"

namespace :masker do
  # Disposable email domains that are MX-valid but obviously for demo/testing
  EMAIL_DOMAINS = %w[
    mailinator.com yopmail.com guerrillamail.com
    tempmail.net dispostable.com fakeinbox.com
  ].freeze

  desc "Mask all private data in the development databases"
  task run: :environment do
    raise "Only run this task in dev!" unless Rails.env.development?

    Parallel.each(Tenant.all) do |tenant|
      Tenant.switch(tenant) do
        Faker::Config.locale = Current.org.default_locale
        emails_mapping = {}
        Member.find_each do |member|
          name = "#{Faker::Name.first_name} #{Faker::Name.last_name}"
          domains = EMAIL_DOMAINS.shuffle
          fake_emails = member.emails_array.each_with_index.map do |email, i|
            fake_email = Faker::Internet.unique.email(name: name, domain: domains[i % domains.size])
            emails_mapping[email.downcase] = fake_email
            fake_email
          end
          fake_iban = member.iban? ? Faker::Bank.iban(country_code: member.country_code) : nil
          member.update_columns(
            name: name,
            emails: fake_emails.join(", "),
            phones: Faker::Base.unique.numerify("+41 ## ### ## ##"),
            street: Faker::Address.street_address,
            city: Faker::Address.city,
            zip: Faker::Address.zip,
            iban: fake_iban,
            note: nil,
            food_note: nil,
            come_from: nil,
            profession: nil)
          billing_name = name
          if member.different_billing_info
            billing_name = Faker::Name.unique.name
            member.update_columns(
              billing_name: billing_name,
              billing_street: Faker::Address.street_address,
              billing_city: Faker::Address.city,
              billing_zip: Faker::Address.zip)
          end
          member.sessions.update_all(email: member.emails_array.first)
          # Update invoices sepa_metadata with anonymized data
          if fake_iban
            member.invoices.where.not(sepa_metadata: {}).find_each do |invoice|
              invoice.update_columns(
                sepa_metadata: invoice.sepa_metadata.merge(
                  "name" => billing_name,
                  "iban" => fake_iban
                ))
            end
          end
        end
        Newsletter::Delivery.where.not(email: nil).find_each do |delivery|
          name = "#{Faker::Name.first_name} #{Faker::Name.last_name}"
          fallback = Faker::Internet.unique.email(name: name, domain: EMAIL_DOMAINS.sample)
          delivery.update_columns(
            email: emails_mapping[delivery.email.downcase] || fallback)
        end
        EmailSuppression.find_each do |suppression|
          name = "#{Faker::Name.first_name} #{Faker::Name.last_name}"
          fallback = Faker::Internet.unique.email(name: name, domain: EMAIL_DOMAINS.sample)
          suppression.update_column(
            :email,
            emails_mapping[suppression.email.downcase] || fallback)
        end
        Admin.find_each do |admin|
          unless admin.email.in?([ ENV["AUTO_SIGN_IN_ADMIN_EMAIL"], ENV["ULTRA_ADMIN_EMAIL"] ])
            name = Faker::Name.unique.first_name
            admin.update_columns(
              name: name,
              email: Faker::Internet.unique.email(name: name, domain: EMAIL_DOMAINS.sample))
          end
        end
        Depot.find_each do |depot|
          attrs = {}
          attrs[:emails] = Faker::Internet.unique.email(name: depot.name, domain: EMAIL_DOMAINS.sample) if depot.emails?
          attrs[:contact_name] = Faker::Name.unique.name if depot.contact_name?
          depot.update_columns(attrs) if attrs.present?
        end

        Faker::UniqueGenerator.clear
      end
    end

    puts "Data masking completed successfully."
  end
end

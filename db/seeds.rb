# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

Tenant.switch_each do
  name = Tenant.current
  domain = "#{name}.test"
  email = "info@#{domain}"
  phone = "+41 76 765 43 21"
  street = "Street 123"
  zip = "1234"
  city = "Metropolis"

  Organization.create!(
    name: name,
    url: "https://#{domain}",
    country_code: "CH",
    languages: [ "en" ],
    email: email,
    fiscal_year_start_month: 1,
    phone: phone,
    creditor_name: name,
    creditor_street: street,
    creditor_city: city,
    creditor_zip: zip,
    billing_year_divisions: [ 1 ],
    invoice_info: "Payable within 30 days. Thank you!",
    invoice_footer: "#{phone} / #{email}",
    email_default_from: email,
    email_footer: "If you have any questions or comments, simply reply to this email.\n#{name}, #{street}, #{zip} #{city}",
    email_signature: "Greetings,\n#{name}")

  Admin.create!(
    email: "admin@#{domain}",
    name: "Admin",
    permission: Permission.superadmin)
end

# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
include FactoryBot::Syntax::Methods

create(:organization,
  name: 'CSA Admin',
  url: 'https://www.csa-admin.org',
  host: "csa-admin",
  email: "info@csa-admin.org",
  phone: "076 449 59 38",
  tenant_name: "csa-admin",
  email_default_host: "https://membres.csa-admin.org",
  email_default_from: "info@csa-admin.org",
  email_signature: "Au plaisir,\nCSA Admin",
  email_footer: "En cas de questions ou remarques, répondez simplement à cet email",
  iban: 'CH0031000000000000000',
  creditor_name: 'CSA Admin',
  creditor_address: "Inconnue 42",
  creditor_city: "La Chaux-de-Fonds",
  creditor_zip: "2300",
  invoice_info: "Payable dans les 30 jours, avec nos remerciements.",
  invoice_footer: "<b>CSA Admin</b>, Inconnue 42, 2300 La Chaux-de-Fonds /// info@csa-admin.org",
  terms_of_service_url: nil)

Organization.switch_each do
  create(:admin,
    name: "Admin",
    email: "admin@example.com")
end

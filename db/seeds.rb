# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
include FactoryBot::Syntax::Methods

create(:acp,
  name: 'ACP Admin',
  url: 'https://www.acp-admin.ch',
  logo_url: 'https://d2ibcm5tv7rtdh.cloudfront.net/demo/logo.png',
  host: "acp-admin",
  email: "info@acp-admin.ch",
  phone: "076 449 59 38",
  tenant_name: "acp-admin",
  email_default_host: "https://membres.acp-admin.ch",
  email_default_from: "info@acp-admin.ch",
  email_signature: "Au plaisir,\nACP Admin",
  email_footer: "En cas de questions ou remarques, répondez simplement à cet email",
  iban: 'CH0031000000000000000',
  creditor_name: 'ACP Admin',
  creditor_address: "Inconnue 42",
  creditor_city: "La Chaux-de-Fonds",
  creditor_zip: "2300",
  invoice_info: "Payable dans les 30 jours, avec nos remerciements.",
  invoice_footer: "<b>ACP Admin</b>, Inconnue 42, 2300 La Chaux-de-Fonds /// info@acp-admin.ch",
  terms_of_service_url: nil)

ACP.switch_each do
  create(:admin,
    name: "Admin",
    email: "admin@example.com")
end

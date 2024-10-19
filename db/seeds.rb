# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

Tenant.create!(:csaadmin) do
  Organization.create!(
    name: 'CSA Admin',
    url: 'https://www.csa-admin.org',
    email: "info@csa-admin.org",
    phone: "076 449 59 38",
    fiscal_year_start_month: 1,
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
    invoice_footer: "<b>CSA Admin</b>, Inconnue 42, 2300 La Chaux-de-Fonds /// info@csa-admin.org")
end

Tenant.switch!(:csaadmin) do
  Admin.create!(
    name: "Admin",
    email: "my@email.com",
    permissions: Permission.superadmin)
end

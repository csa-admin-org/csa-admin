# frozen_string_literal: true

module OrganizationsHelper
  def org(columns = {})
    Current.org.update_columns(columns)
  end

  def german_org(columns = {})
    Current.org.update!({
      languages: [ "de" ],
      country_code: "DE",
      currency_code: "EUR",
      iban: "DE87200500001234567890",
      invoice_info: "Zahlbar innerhalb der nächsten zwei Wochen",
      new_member_fee_description: "Skipped",
      invoice_sepa_info: "Skipped",
      creditor_name: "Gläubiger GmbH",
      creditor_street: "Sonnenallee 1",
      creditor_city: "Hannover",
      creditor_zip: "30159"
    }.merge(columns))
  end

  def france_org(columns = {})
    org({
      languages: [ "fr" ],
      country_code: "FR",
      currency_code: "EUR",
      iban: "FR1420041010050500013M02606",
      creditor_name: "Jardin Réunis",
      creditor_street: "1 rue de la Paix",
      creditor_city: "Paris",
      creditor_zip: "75000"
    }.merge(columns))
  end
end

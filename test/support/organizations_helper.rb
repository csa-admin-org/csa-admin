# frozen_string_literal: true

module OrganizationsHelper
  def org(columns = {})
    Current.org.update_columns(columns)
  end

  def corrupt_icalendar_auth_token!(organization = Current.org)
    ciphertext = JSON.parse(organization.ciphertext_for(:icalendar_auth_token))
    ciphertext["p"] = ciphertext.fetch("p").tr("A-Za-z0-9", "B-ZAb-z0-91")
    # Raw SQL: update_column would re-encrypt this payload as plaintext.
    Organization.connection.update(
      Organization.sanitize_sql_array([
        "UPDATE organizations SET icalendar_auth_token = ? WHERE id = ?",
        ciphertext.to_json,
        organization.id
      ]))
  end

  def german_org(columns = {})
    attrs = {
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
      creditor_zip: "30159",
      basket_content_member_title_de: "Ihr Tascheninhalt"
    }.merge(columns)
    if attrs[:sepa_creditor_identifier].present? && !columns.key?(:features)
      attrs[:features] = Current.org.features | [ :sepa ]
    end

    Current.org.update!(attrs)
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

  def dutch_org(columns = {})
    org({
      languages: [ "nl" ],
      country_code: "NL",
      currency_code: "EUR",
      iban: "NL91ABNA0417164300",
      creditor_name: "Boerderij Mooi",
      creditor_street: "Kerkstraat 1",
      creditor_city: "Amsterdam",
      creditor_zip: "1012 AB"
    }.merge(columns))
  end
end

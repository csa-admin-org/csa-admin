# frozen_string_literal: true

require "test_helper"

class PDF::InvoiceTest < ActiveSupport::TestCase
  def save_pdf_and_return_strings(invoice)
    pdf = I18n.with_locale(invoice.member.language) do
      PDF::Invoice.new(invoice)
    end
    pdf.render_file(Rails.root.join("tmp/invoice.pdf"))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  test "simple invoice full layout" do
    invoice = invoices(:annual_fee)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_equal [
      "Invoice N°\u00A0#{invoice.id}",
      "1 April 2024",
      "Martha", "Nowhere 46", "1234 City",
      "Member No.: #{invoice.member_id}",
      "Description", "Amount (CHF)",
      "Annual fee", "30.00",
      "Total", "30.00",
      "Payable within 30 days, with our thanks.",
      "Acme", ", Nowhere 42, 1234 City // info@acme.test",
      "Receipt",
      "Account / Payable to",
      "CH44 3199 9123 0008 8901 2",
      "Acme", "Nowhere 42", "1234 City",
      "Reference", "00 00000 06148 57506 38928 10045",
      "Payable by", "Martha", "Nowhere 46", "1234 City",
      "Currency", "CHF",
      "Amount", "30.00",
      "Acceptance point",
      "Payment part",
      "Currency", "CHF",
      "Amount", "30.00",
      "Account / Payable to", "CH44 3199 9123 0008 8901 2",
      "Acme", "Nowhere 42", "1234 City",
      "Reference", swiss_qr_ref(invoice).formatted,
      "Further information",
      "Invoice #{invoice.id}",
      "Payable by", "Martha", "Nowhere 46", "1234 City"
    ], pdf_strings
  end

  test "use different billing info" do
    invoice = invoices(:annual_fee)
    invoice.member.update!(
      billing_name: "Martha Office",
      billing_address: "Nowhere 42",
      billing_city: "Office City",
      billing_zip: "4321")

    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Invoice N°\u00A0#{invoice.id}",
      "1 April 2024",
      "Martha Office", "Nowhere 42", "4321 Office City",
      "Member No.: #{invoice.member_id}"
    ]
    assert_contains pdf_strings, [
      "Account / Payable to",
      "CH44 3199 9123 0008 8901 2",
      "Acme", "Nowhere 42", "1234 City",
      "Reference", "00 00000 06148 57506 38928 10045",
      "Payable by", "Martha Office", "Nowhere 42", "4321 Office City"
    ]
    assert_contains pdf_strings, [
      "Further information",
      "Invoice #{invoice.id}",
      "Payable by", "Martha Office", "Nowhere 42", "4321 Office City"
    ]
  end

  test "shares number (positive)" do
    org(share_price: 100)
    invoice = create_invoice(shares_number: 2)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Acquisition of 2 share certificates", "200.00",
      "Total", "200.00"
    ]
    assert_not_includes pdf_strings, "Remaining credit"
  end

  test "shares number (negative)" do
    org(share_price: 100)
    create_payment(amount: 75)
    invoice = create_invoice(shares_number: -2)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Refund of 2 share certificates", "-200.00",
      "Total", "-200.00",
      "Remaining credit", "275.00"
    ]
  end

  test "annual membership with annual fee and complements" do
    travel_to "2024-01-01"
    memberships(:jane).update!(
      baskets_annual_price_change: -33,
      basket_complements_annual_price_change: 5)
    invoice = create_invoice(
      entity: memberships(:jane),
      annual_fee: 30,
      memberships_amount_description: "Annual amount")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_includes pdf_strings, "01.01.24 – 31.12.24"
    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Large basket 10x 30.00", "300.00",
      "Adjustment of the price of baskets", "-33.00",
      "Bread: 10x 4.00", "40.00",
      "Adjustment of the price of supplements", "5.00",
      "Depot: Bakery 10x 4.00", "40.00",
      "Annual amount", "352.00",
      "Annual amount", "352.00",
      "Annual fee", "30.00",
      "Total", "382.00"
    ]
  end

  test "annual membership with activity_participations reduction" do
    travel_to "2024-01-01"
    memberships(:john).update!(
      activity_participations_demanded_annually: 4,
      activity_participations_annual_price_change: -120)
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: nil,
      memberships_amount_description: "Annual amount")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Discount for 2 additional ", "½ ", "days", "-120.00",
      "Annual amount", "80.00",
      "Annual amount", "80.00"
    ]
  end

  test "annual membership with basket price extra" do
    travel_to "2024-01-01"
    memberships(:john).update!(basket_price_extra: 4)
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: nil,
      memberships_amount_description: "Annual amount")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Support: 10x 4.00", "40.00",
      "Annual amount", "240.00",
      "Annual amount", "240.00"
    ]
  end

  test "annual membership with basket price extra and dynamic pricing" do
    travel_to "2024-01-01"
    Current.org.update!(
      basket_price_extra_label: "Class {{ extra | floor }}",
      basket_price_extra_dynamic_pricing: "4.2")
    memberships(:john).update!(basket_price_extra: 4)
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: nil,
      memberships_amount_description: "Annual amount")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Support: 10x 4.20, Class 4", "42.00",
      "Annual amount", "242.00",
      "Annual amount", "242.00"
    ]
  end

  test "annual membership with membership delivery cycle price" do
    travel_to "2024-01-01"
    memberships(:john).update!(delivery_cycle_price: 3)
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: nil,
      memberships_amount_description: "Annual amount")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Deliveries: Mondays 10x 3.00", "30.00",
      "Annual amount", "230.00",
      "Annual amount", "230.00"
    ]
  end

  test "annual membership with membership delivery cycle price and custom invoice name" do
    travel_to "2024-01-01"
    memberships(:john).update!(delivery_cycle_price: 3)
    memberships(:john).delivery_cycle.update!(invoice_name: "Custom Name")
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: nil,
      memberships_amount_description: "Annual amount")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Custom Name 10x 3.00", "30.00",
      "Annual amount", "230.00",
      "Annual amount", "230.00"
    ]
  end

  test "quarter membership with annual fee" do
    travel_to "2024-04-01"
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: 30,
      membership_amount_fraction: 4,
      memberships_amount_description: "Quarterly amount #1")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Annual amount", "200.00",
      "Quarterly amount #1", "50.00",
      "Annual fee", "30.00",
      "Total", "80.00"
    ]
  end

  test "quarter membership and positive balance" do
    travel_to "2024-01-01"
    create_payment(amount: 40)
    invoice = create_invoice(
      entity: memberships(:john),
      membership_amount_fraction: 4,
      memberships_amount_description: "Quarterly amount #2")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Annual amount", "200.00",
      "Quarterly amount #2", "50.00",
      "Balance", "* -40.00",
      "To be paid", "10.00",
      "* Difference between all existing invoices and all payments made at the time of issuing this invoice.",
      "The history of your invoices can be viewed at any time on your member page."
    ]
  end

  test "quarter membership and positive balance (over the price)" do
    travel_to "2024-01-01"
    create_payment(amount: 100)
    invoice = create_invoice(
      entity: memberships(:john),
      membership_amount_fraction: 4,
      memberships_amount_description: "Quarterly amount #2")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Annual amount", "200.00",
      "Quarterly amount #2", "50.00",
      "Balance", "* -100.00",
      "To be paid", "0.00",
      "Remaining credit", "50.00",
      "* Difference between all existing invoices and all payments made at the time of issuing this invoice.",
      "The history of your invoices can be viewed at any time on your member page."
    ]
  end

  test "activity participations" do
    travel_to "2024-01-01"
    invoice = create_invoice(
      entity: activity_participations(:john_harvest),
      memberships_amount_description: "Quarterly amount #2")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Missed half-day on 1 July 2024 (2 participants)", "100.00",
      "Total", "100.00"
    ]
  end

  test "activity participations with VAT" do
    travel_to "2024-01-01"
    org(vat_activity_rate: 8.1, vat_number: "CHE-123.456.789")
    invoice = create_invoice(
      entity: activity_participations(:john_harvest))
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Missed half-day on 1 July 2024 (2 participants)", "100.00",
      "Total", "* 100.00",
      "* All taxes included, CHF 92.51 Without taxes, CHF 7.49 VAT (8.1%)",
      "N° VAT CHE-123.456.789"
    ]
  end

  test "activity participations (participant_count and fiscal_year overwrite)" do
    travel_to "2024-01-01"
    org(fiscal_year_start_month: 4)
    invoice = create_invoice(
      entity_type: "ActivityParticipation",
      missing_activity_participations_count: 3,
      missing_activity_participations_fiscal_year: 2023)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [ "Invoice N°\u00A0#{invoice.id}", "1 January 2024" ]
    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "3 missed half-days (2023-24)", "150.00",
      "Total", "150.00"
    ]
  end

  test "with items" do
    invoice = create_invoice(
      items_attributes: {
        "0" => { description: "A cool cheap thing", amount: 10 },
        "1" => { description: "A cool less cheap thing", amount: 32 }
      })
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "A cool cheap thing", "10.00",
      "A cool less cheap thing", "32.00",
      "Total", "42.00"
    ]
  end

  test "with items, payment, percentage, and TVA" do
    org(vat_number: "CHE-123.456.789")
    create_payment(amount: 21)
    invoice = create_invoice(
      vat_rate: 2.5,
      amount_percentage: 4.2,
      items_attributes: {
        "0" => { description: "A cool cheap thing", amount: 10 },
        "1" => { description: "A cool less cheap thing", amount: 32 }
      })
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "A cool cheap thing", "10.00",
      "A cool less cheap thing", "32.00",
      "Total (before percentage)", "42.00",
      "+4.2%", "1.76",
      "Total", "* 43.76",
      "Balance", "** -21.00",
      "To be paid", "22.76",
      "* All taxes included, CHF 42.69 Without taxes, CHF 1.07 VAT (2.5%)",
      "N° VAT CHE-123.456.789",
      "** Difference between all existing invoices and all payments made at the time of issuing this invoice.",
      "The history of your invoices can be viewed at any time on your member page."
    ]
  end

  test "over 2 pages" do
    invoice = create_invoice(items_attributes: 50.times.map { |i|
      [ i, { description: "A thing", amount: 10 } ]
    }.to_h)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_includes pdf_strings, "1 / 2"
    assert_includes pdf_strings, "2 / 2"
  end

  test "over 3 pages" do
    invoice = create_invoice(items_attributes: 51.times.map { |i|
      [ i, { description: "A thing", amount: 10 } ]
    }.to_h)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_includes pdf_strings, "1 / 3"
    assert_includes pdf_strings, "2 / 3"
    assert_includes pdf_strings, "3 / 3"
  end

  test "shop order" do
    Current.org.update!(
      shop_invoice_info: "Invoice of you shop order of %{date}.")
    order = create_shop_order(
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_500).id,
          item_price: 9.9,
          quantity: 2
        },
        "1" => {
          product_id: shop_products(:flour).id,
          product_variant_id: shop_product_variants(:flour_wheat).id,
          quantity: 3
        }
      })
    invoice = order.invoice!
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_includes pdf_strings, "Invoice N°\u00A0#{invoice.id}"
    assert_contains pdf_strings, [
      "Order N°\u00A0#{order.id}",
      "Delivery: 4 April 2024"
    ]
    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Oil, Olive 500ml, 2x 9.90", "19.80",
      "Flour, Wheat 1kg, 3x 3.00", "9.00",
      "Total", "28.80",
      "Invoice of you shop order of 4 April 2024.",
      "Payable within 30 days, with our thanks."
    ]
  end

  test "new member fee" do
    travel_to "2023-05-01"
    invoice = Billing::InvoicerNewMemberFee.invoice(members(:john))
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Empty baskets", "33.00",
      "Total", "33.00"
    ]
  end

  test "France invoice" do
    france_org
    members(:martha).update!(language: "fr")
    invoice = invoices(:annual_fee)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_equal [
      "Facture N°\u00A0#{invoice.id}",
      "1 avril 2024",
      "Martha",
      "Nowhere 46", "1234 City",
      "N° membre: #{invoice.member_id}",
      "Description", "Montant (", "€", ")",
      "Cotisation annuelle", "30.00",
      "Total", "30.00",
      "Paiement",
      "Montant", "EUR 30.00",
      "Payable à",
      "Jardin Réunis", "1 rue de la Paix", "75000 Paris",
      "IBAN: ", "FR14 2004 1010 0505 0001 3M02 606",
      "Numéro de référence / Motif du paiement", invoice.reference.formatted,
      "Payable par",
      "Martha", "Nowhere 46", "1234 City"
    ], pdf_strings
  end

  test "Germany invoice (Girocode QR)" do
    german_org
    members(:martha).update!(
      language: "de",
      address: "Grosse Marktgasse 28",
      zip: "30952",
      city: "Ronnenberg",
      country_code: "DE")

    invoice = invoices(:annual_fee)
    invoice.update!(id: 12345678)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_equal [
      "Rechnung N°\u00A0#{invoice.id}",
      "1. April 2024",
      "Martha",
      "Grosse Marktgasse 28", "30952 Ronnenberg",
      "Mitgliedsnummer: #{invoice.member_id}",
      "Beschreibung", "Betrag (", "€", ")",
      "Jahresbeitrag", "30.00",
      "Gesamt", "30.00",
      "Zahlbar innerhalb der nächsten zwei Wochen",
      "Zahlteil",
      "Zahlen mit Code",
      "IBAN", "DE87 2005 0000 1234 5678 90",
      "Zahlbar an",
      "Gläubiger GmbH",
      "Referenznummer / Verwendungszweck", invoice.reference.formatted,
      "Betrag", "EUR 30.00"
    ], pdf_strings
  end

  test "Germany annual_fee invoice (SEPA)" do
    travel_to "2024-01-01"
    german_org(
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999",
      invoice_document_name: "Mitgliedsbestätigung",
      invoice_sepa_info: "Der Rechnungsbetrag wird per SEPA-Lastschrift automatisch eingezogen. Bitte stellen Sie sicher, dass Ihr Konto ausreichend gedeckt ist.")
    member = members(:anna)
    member.update!(
      language: "de",
      iban: "DE21500500009876543210",
      sepa_mandate_id: "123456",
      sepa_mandate_signed_on: "2023-12-24",
      address: "Grosse Marktgasse 28",
      zip: "30952",
      city: "Ronnenberg",
      country_code: "DE")

    invoice = create_annual_fee_invoice(id: 412351, member: member)
    assert_equal({
      "name" => "Anna Doe",
      "iban" => "DE21500500009876543210",
      "mandate_id" => "123456",
      "mandate_signed_on" => "2023-12-24"
    }, invoice.sepa_metadata)

    pdf_strings = save_pdf_and_return_strings(invoice)
    assert_equal [
      "Mitgliedsbestätigung", "N°\u00A0#{invoice.id}",
      "1. Januar 2024",
      "Anna Doe",
      "Grosse Marktgasse 28", "30952 Ronnenberg",
      "Mitgliedsnummer: #{member.id}",
      "Beschreibung", "Betrag (", "€", ")",
      "Jahresbeitrag", "30.00",
      "Gesamt", "30.00",
      "Der Rechnungsbetrag wird per SEPA-Lastschrift automatisch eingezogen. Bitte stellen Sie sicher, dass Ihr Konto ausreichend gedeckt ist.",
      "SEPA-Lastschriftverfahren",
      "Betrag", "EUR 30.00",
      "Zahlbar an",
      "Gläubiger GmbH", "Sonnenallee 1", "30159 Hannover",
      "IBAN: ", "DE87 2005 0000 1234 5678 90",
      "Gläubiger-ID: ", "DE98ZZZ09999999999",
      "Referenznummer / Verwendungszweck", invoice.reference.formatted,
      "Zahlbar durch",
      "Anna Doe", "Grosse Marktgasse 28", "30952 Ronnenberg",
      "IBAN: ", "DE21 5005 0000 9876 5432 10",
      "SEPA Mandatsreferenz: ", "123456", " (24. Dez 23)"
    ], pdf_strings
  end

  test "includes previous cancelled invoices references" do
    part = activity_participations(:john_harvest)
    i1 = create_invoice(entity: part)
    i1.update_columns(state: "canceled", canceled_at: Time.current)
    i2 = create_invoice(entity: part)
    i2.update_columns(state: "canceled", canceled_at: Time.current)
    i3 = create_invoice(entity: part)

    assert_includes save_pdf_and_return_strings(i3),
      "This corrective invoice replaces the canceled invoices no. #{i1.id} and #{i2.id}."
  end
end

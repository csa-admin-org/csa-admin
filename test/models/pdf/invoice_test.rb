# frozen_string_literal: true

require "test_helper"

class PDF::InvoiceTest < ActiveSupport::TestCase
  def save_pdf_and_return_strings(invoice)
    pdf = PDF::Invoice.new(invoice)
    pdf.render_file(Rails.root.join("tmp/invoice.pdf"))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  test "simple invoice full layout" do
    invoice = invoices(:annual_fee)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_equal [
      "Invoice N° #{invoice.id}",
      "1 April 2024",
      "Martha", "Nowhere 46", "1234 City",
      "Description", "Amount (CHF)",
      "Annual association fee", "30.00",
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
      memberships_amount_description: "Annual billing")
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
      "Annual billing", "352.00",
      "Annual association fee", "30.00",
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
      memberships_amount_description: "Annual billing")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Discount for 2 additional ", "½ ", "days", "-120.00",
      "Annual amount", "80.00",
      "Annual billing", "80.00"
    ]
  end

  test "annual membership with basket price extra" do
    travel_to "2024-01-01"
    memberships(:john).update!(basket_price_extra: 4)
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: nil,
      memberships_amount_description: "Annual billing")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Support: 10x 4.00", "40.00",
      "Annual amount", "240.00",
      "Annual billing", "240.00"
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
      memberships_amount_description: "Annual billing")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Support: 10x 4.20, Class 4", "42.00",
      "Annual amount", "242.00",
      "Annual billing", "242.00"
    ]
  end

  test "annual membership with membership delivery cycle price" do
    travel_to "2024-01-01"
    memberships(:john).update!(delivery_cycle_price: 3)
    invoice = create_invoice(
      entity: memberships(:john),
      annual_fee: nil,
      memberships_amount_description: "Annual billing")
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Basket: Medium basket 10x 20.00", "200.00",
      "Deliveries (Mondays): 10x 3.00", "30.00",
      "Annual amount", "230.00",
      "Annual billing", "230.00"
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
      "Annual association fee", "30.00",
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

    assert_contains pdf_strings, [ "Invoice N° #{invoice.id}", "1 January 2024" ]
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

    assert_includes pdf_strings, "Invoice N° #{invoice.id}"
    assert_contains pdf_strings, [
      "Order N° #{order.id}",
      "Delivery: 4 April 2024"
    ]
    assert_contains pdf_strings, [
      "Description", "Amount (CHF)",
      "Oil, Olive 500ml, 2x 9.90", "19.80",
      "Flour, Wheat 1kg, 3x 3.00", "9.00",
      "Total", "28.80"
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
    org(
      country_code: "FR",
      currency_code: "EUR",
      iban: "FR1420041010050500013M02606",
      creditor_name: "Jardin Réunis",
      creditor_address: "1 rue de la Paix",
      creditor_city: "Paris",
      creditor_zip: "75000")
    invoice = invoices(:annual_fee)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_equal [
      "Invoice N° #{invoice.id}",
      "1 April 2024",
      "Martha",
      "Nowhere 46", "1234 City",
      "Description", "Amount (", "€", ")",
      "Annual association fee", "30.00",
      "Total", "30.00",
      "Payable within 30 days, with our thanks.",
      "Acme", ", Nowhere 42, 1234 City // info@acme.test",
      "Payment part",
      "Amount", "30.00",
      "Payable to",
      "Jardin Réunis", "1 rue de la Paix", "75000 Paris",
      "IBAN: ", "FR14 2004 1010 0505 0001 3M02 606",
      "Invoice number / Reference", "#{invoice.id}",
      "Payable by",
      "Martha", "Nowhere 46", "1234 City"
    ], pdf_strings
  end

  test "Germany invoice (Girocode QR)" do
    Current.org.update!(
      country_code: "DE",
      currency_code: "EUR",
      iban: "DE87200500001234567890",
      creditor_name: "Gläubiger GmbH",
      creditor_address: "Sonnenallee 1",
      creditor_city: "Hannover",
      creditor_zip: "30159")
    members(:martha).update!(
      address: "Grosse Marktgasse 28",
      zip: "30952",
      city: "Ronnenberg",
      country_code: "DE")

    invoice = invoices(:annual_fee)
    pdf_strings = save_pdf_and_return_strings(invoice)

    assert_equal [
      "Invoice N° #{invoice.id}",
      "1 April 2024",
      "Martha",
      "Grosse Marktgasse 28", "30952 Ronnenberg",
      "Description", "Amount (", "€", ")",
      "Annual association fee", "30.00",
      "Total", "30.00",
      "Payable within 30 days, with our thanks.",
      "Acme", ", Nowhere 42, 1234 City // info@acme.test",
      "Payment part",
      "Pay with code",
      "IBAN", "DE87 2005 0000 1234 5678 90",
      "Payable to",
      "Gläubiger GmbH",
      "Reference",
      "RF79 1485 7506 8928 1004",
      "Amount",
      "EUR 30.00"
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

require "rails_helper"

describe PDF::Invoice do
  let(:member) { create(:member, id: 4242) }
  context "Rage de Vert settings" do
    before {
      Current.acp.update!(
        name: "rdv",
        iban: "CH44 3199 9123 0008 8901 2",
        bank_reference: "11041",
        invoice_info: "Payable dans les 30 jours, avec nos remerciements.",
        invoice_footer: "<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84")
    }

    it "generates invoice with all settings and member name and address", sidekiq: :inline do
      member = create(:member,
        name: "John Doe",
        address: "Unknown Str. 42",
        zip: "0123",
        city: "Nowhere")
      invoice = create(:invoice, :annual_fee, id: 706, member: member)

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include("Facture N° 706")
        .and contain_sequence("John Doe", "Unknown Str. 42", "0123 Nowhere")
        .and contain_sequence("Association Rage de Vert", "Closel-Bourbon 3", "2075 Thielle")
        .and include("CH44 3199 9123 0008 8901 2")
    end

    it "generates invoice with only annual_fee amount", sidekiq: :inline do
      invoice = create(:invoice, :annual_fee, member: member, id: 807, annual_fee: 42)
      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence("Cotisation annuelle association", "42.00")
        .and include("11 04100 00000 04242 00000 08078")
      expect(pdf_strings).not_to include("Facturation annuelle")
    end

    it "generates invoice with annual_fee amount + annual membership", sidekiq: :inline do
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        deliveries_count: 2)
      invoice = create(:invoice,
        id: 4,
        member: member,
        entity: membership,
        annual_fee: 42,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence("Panier: Abondance PUBLIC 2x 33.25", "66.50")
        .and contain_sequence("Montant annuel", "66.50", "Facturation annuelle", "66.50")
        .and contain_sequence("Cotisation annuelle association", "42.00")
        .and contain_sequence("Total", "108.50")
        .and include "11 04100 00000 04242 00000 00049"
      expect(pdf_strings).not_to include "Montant annuel restant"
    end

    it "generates invoice with support ammount + annual membership + activity_participations reduc", sidekiq: :inline do
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        activity_participations_demanded_annually: 8,
        activity_participations_annual_price_change: -20.50,
        deliveries_count: 2)
      invoice = create(:invoice,
        id: 7,
        member: member,
        entity: membership,
        annual_fee: 30,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence("Panier: Abondance PUBLIC 2x 33.25", "66.50")
        .and contain_sequence("Réduction pour 6 ", "½ ", "journées supplémentaires", "-20.50")
        .and contain_sequence("Montant annuel", "46.00", "Facturation annuelle", "46.00")
        .and contain_sequence("Cotisation annuelle association", "30.00")
        .and contain_sequence("Total", "76.00")
        .and include "11 04100 00000 04242 00000 00070"
      expect(pdf_strings).not_to include "Montant annuel restant"
    end

    it "generates invoice with support ammount + quarter membership", sidekiq: :inline do
      member = create(:member, id: 4444, billing_year_division: 4)
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :small, price: "23.125"),
        depot: create(:depot, name: "La Chaux-de-Fonds", price: 4),
        deliveries_count: 2)
      invoice =  create(:invoice,
        id: 8,
        member: member,
        entity: membership,
        annual_fee: 30,
        membership_amount_fraction: 4,
        memberships_amount_description: "Montant trimestriel #1")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence("Panier: Eveil PUBLIC 2x 23.125", "46.25")
        .and contain_sequence("Dépôt: La Chaux-de-Fonds PUBLIC 2x 4.00", "8.00")
        .and contain_sequence("Montant annuel", "54.25")
        .and contain_sequence("Montant trimestriel #1", "13.55")
        .and contain_sequence("Cotisation annuelle association", "30.00")
        .and contain_sequence("Total", "43.55")
        .and include "11 04100 00000 04444 00000 00080"
    end

    it "generates invoice with membership basket_price_extra", sidekiq: :inline do
      Current.acp.update!(
        features: [ "basket_price_extra" ],
        basket_price_extra_title: "Prix Extra",
        basket_price_extra_public_title: "Cotistation Solidaire")
      membership = create(:membership,
        basket_price_extra: 4,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        deliveries_count: 2)
      invoice = create(:invoice,
        id: 4,
        entity: membership,
        annual_fee: 42,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence("Panier: Abondance PUBLIC 2x 33.25", "66.50")
        .and contain_sequence("Cotistation Solidaire: 2x 4.00", "8.00")
        .and contain_sequence("Cotisation annuelle association", "42.00")
        .and contain_sequence("Total", "116.50")
    end

    it "generates invoice with membership basket_price_extra and dynamic pricing", sidekiq: :inline do
      Current.acp.update!(
        features: [ "basket_price_extra" ],
        basket_price_extra_title: "Classe",
        basket_price_extra_public_title: "Classe salariale",
        basket_price_extra_label: "Classe {{ extra | floor }}",
        basket_price_extra_dynamic_pricing: "4.2")

      membership = create(:membership,
        basket_price_extra: 4,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        deliveries_count: 2)
      invoice = create(:invoice,
        id: 4,
        entity: membership,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence("Panier: Abondance PUBLIC 2x 33.25", "66.50")
        .and contain_sequence("Classe salariale: 2x 4.20, Classe 4", "8.40")
        .and contain_sequence("Montant annuel", "74.90")
    end

    it "generates invoice with quarter menbership and paid amount", sidekiq: :inline do
      member = create(:member, id: 42, billing_year_division: 4)
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        deliveries_count: 2)
      create(:invoice,
        date: Time.current.beginning_of_year,
        member: member,
        entity: membership,
        membership_amount_fraction: 4,
        memberships_amount_description: "Facturation trimestrielle #1")
      create(:invoice,
        date: Time.current.beginning_of_year + 4.months,
        member: member,
        entity: membership,
        membership_amount_fraction: 3,
        memberships_amount_description: "Facturation trimestrielle #2")
      invoice = create(:invoice,
        id: 1001,
        date: Time.current.beginning_of_year + 8.months,
        member: member,
        entity: membership,
        membership_amount_fraction: 2,
        memberships_amount_description: "Facturation trimestrielle #3")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence("Panier: Abondance PUBLIC 2x 33.25", "66.50",)
        .and contain_sequence("Déjà facturé", "-33.25")
        .and contain_sequence("Montant annuel restant", "33.25")
        .and contain_sequence("Facturation trimestrielle #3", "16.65")
        .and include("11 04100 00000 00042 00000 10013")
      expect(pdf_strings).not_to include "Cotisation annuelle association"
    end

    it "generates invoice with ActivityParticipation object", sidekiq: :inline do
      activity = create(:activity, date: "2018-3-4")
      rejected_participation = create(:activity_participation, :rejected,
        activity: activity)
      invoice = create(:invoice,
        id: 2001,
        date: "2018-4-5",
        entity: rejected_participation,
        paid_missing_activity_participations: 2)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("½ ", "journée du 4 mars 2018 non-effectuée (2 participants)", "120.00")
        .and contain_sequence("Total", "120.00")
    end

    specify "invoice with ActivityParticipation object and VAT", sidekiq: :inline do
      Current.acp.update!(
        vat_activity_rate: 7.7,
        vat_number: "CHE-123.456.789",
        activity_price: 60)
      activity = create(:activity, date: "2018-3-4")
      invoice = create(:invoice,
        id: 20011,
        date: "2023-1-13",
        paid_missing_activity_participations: 2)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("Total", "* 120.00")
        .and contain_sequence("* TTC, CHF 111.42 HT, CHF 8.58 TVA (7.7%)")
        .and contain_sequence("N° TVA CHE-123.456.789")
    end

    it "generates invoice with ActivityParticipation type (one participant)", sidekiq: :inline do
      invoice = create(:invoice,
        id: 2002,
        date: "2018-4-5",
        paid_missing_activity_participations: 1)

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence("½ ", "journée non-effectuée", "60.00")
        .and contain_sequence("Total", "60.00")
    end

    it "generates invoice with ActivityParticipation type (many participants)", sidekiq: :inline do
      invoice = create(:invoice,
        id: 2003,
        date: "2018-4-5",
        paid_missing_activity_participations: 3,
        activity_price: 60)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("3 ", "½ ", "journées non effectuées", "180.00")
        .and contain_sequence("Total", "180.00")
    end

    it "generates an invoice with items", sidekiq: :inline do
      invoice = create(:invoice,
        id: 2010,
        date: "2018-11-01",
        items_attributes: {
          "0" => { description: "Un truc cool pas cher", amount: 10 },
          "1" => { description: "Un truc cool plus cher", amount: 32 }
        })

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence("Un truc cool pas cher", "10.00")
        .and contain_sequence("Un truc cool plus cher", "32.00")
        .and contain_sequence("Total", "42.00")
    end

    it "generates an invoice with items and percentage", sidekiq: :inline do
      invoice = create(:invoice,
        id: 2010,
        date: "2018-11-01",
        amount_percentage: 4.2,
        items_attributes: {
          "0" => { description: "Un truc cool pas cher", amount: 10 },
          "1" => { description: "Un truc cool plus cher", amount: 32 }
        })

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("Un truc cool pas cher", "10.00")
        .and contain_sequence("Un truc cool plus cher", "32.00")
        .and contain_sequence("Total (avant pourcentage)", "42.00")
        .and contain_sequence("+4.2%", "1.75")
        .and contain_sequence("Total", "43.75")
    end

    it "generates an invoice with items and VAT", sidekiq: :inline do
      Current.acp.update!(vat_number: "CHE-123.456.789")
      payment = create(:payment, amount: 12)
      invoice = create(:invoice,
        id: 20101,
        date: "2023-01-14",
        member: payment.member,
        vat_rate: 2.5,
        items_attributes: {
          "0" => { description: "Un truc cool pas cher", amount: 10 },
          "1" => { description: "Un truc cool plus cher", amount: 32 }
        })

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence("Un truc cool pas cher", "10.00")
        .and contain_sequence("Un truc cool plus cher", "32.00")
        .and contain_sequence("Total", "* 42.00")
        .and contain_sequence("Balance", "** -12.00")
        .and contain_sequence("À payer", "30.00")
        .and contain_sequence("* TTC, CHF 40.98 HT, CHF 1.02 TVA (2.5%)")
        .and contain_sequence("N° TVA CHE-123.456.789")
    end

    specify "with items over 2 pages", sidekiq: :inline do
      invoice = create(:invoice,
        id: 20101,
        date: "2023-05-05",
        items_attributes: 50.times.map { |i|
          [ i, { description: "Un truc", amount: 10 } ]
        }.to_h)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("1 / 2")
        .and contain_sequence("2 / 2")
    end

    specify "with items over 3 pages", sidekiq: :inline do
      invoice = create(:invoice,
        id: 20101,
        date: "2023-05-05",
        items_attributes: 51.times.map { |i|
          [ i, { description: "Un truc", amount: 10 } ]
        }.to_h)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("1 / 3")
        .and contain_sequence("2 / 3")
        .and contain_sequence("3 / 3")
    end
  end

  context "Lumiere des Champs settings" do
    before {
      Current.acp.update!(
        name: "ldc",
        logo_url: "https://d2ibcm5tv7rtdh.cloudfront.net/lumieredeschamps/logo.jpg",
        fiscal_year_start_month: 4,
        vat_membership_rate: 0.1,
        vat_number: "CHE-273.220.900",
        bank_reference: "800250",
        invoice_info: "Payable dans les 30 jours, avec nos remerciements.",
        invoice_footer: "<b>Association Lumière des Champs</b>, Bd Paderewski 28, 1800 Vevey – comptabilite@lumiere-des-champs.ch")
      create_deliveries(4)
    }

    it "generates invoice with support amount + complements + annual membership", sidekiq: :inline do
      member = create(:member,
        id: 42,
        name: "Alain Reymond",
        address: "Bd Plumhof 6",
        zip: "1800",
        city: "Vevey")
      create(:basket_complement,
        id: 1,
        name: "Oeufs",
        price: 4.8,
        delivery_ids: Delivery.current_year.pluck(:id)[0..1])
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: "Tomme de Lavaux",
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        basket_size: create(:basket_size, name: "Grand"),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: 1 },
          "1" => { basket_complement_id: 2 }
        })
      invoice = create(:invoice,
        id: 122,
        member: member,
        entity: membership,
        annual_fee: 75,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence("Panier: Grand PUBLIC 4x 30.50", "122.00")
        .and contain_sequence("Oeufs PUBLIC: 2x 4.80", "9.60")
        .and contain_sequence("Tomme de Lavaux PUBLIC: 2x 7.40", "14.80")
        .and contain_sequence("Montant annuel", "146.40", "Facturation annuelle", "* 146.40")
        .and contain_sequence("Cotisation annuelle association", "75.00")
        .and contain_sequence("Total", "221.40")
        .and contain_sequence("* TTC, CHF 146.25 HT, CHF 0.15 TVA (0.1%)")
        .and contain_sequence("N° TVA CHE-273.220.900")
        .and include "80 02500 00000 00042 00000 01221"
      expect(pdf_strings).not_to include "Montant annuel restant"
    end

    it "generates invoice with support ammount + four month membership + winter basket", freeze: "2019-04-01", sidekiq: :inline do
      create(:delivery, date: "2019-10-01")
      winter_dc = create(:delivery_cycle, months: [ 1, 2, 3, 10, 11, 12 ])
      member = create(:member,
        name: "Alain Reymond",
        address: "Bd Plumhof 6",
        zip: "1800",
        city: "Vevey")
      membership = create(:membership,
        basket_size: create(:basket_size, name: "Grand"),
        depot: create(:depot, price: 0, delivery_cycles: [ winter_dc ]),
        basket_price: 30.5)
      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        entity: membership,
        annual_fee: 75,
        membership_amount_fraction: 3,
        memberships_amount_description: "Facturation quadrimestrielle #1")
      invoice = create(:invoice,
        id: 125,
        date: Current.fy_range.min + 4.month,
        member: member,
        entity: membership,
        membership_amount_fraction: 2,
        memberships_amount_description: "Facturation quadrimestrielle #2")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("01.04.2019 – 31.03.2020")
        .and contain_sequence("Panier: Grand PUBLIC 1x 30.50", "30.50")
        .and contain_sequence("Déjà facturé", "-10.15")
        .and contain_sequence("Montant annuel restant", "20.35")
        .and contain_sequence("Facturation quadrimestrielle #2", "* 10.20")
        .and contain_sequence("* TTC, CHF 10.19 HT, CHF 0.01 TVA (0.1%)")
        .and contain_sequence("N° TVA CHE-273.220.900")
      expect(pdf_strings).not_to include "Cotisation annuelle association"
    end

    it "generates invoice with mensual membership + complements", sidekiq: :inline do
      member = create(:member,
        name: "Alain Reymond",
        address: "Bd Plumhof 6",
        zip: "1800",
        city: "Vevey")
      create(:basket_complement,
        id: 1,
        name: "Oeufs",
        price: 4.8,
        delivery_ids: Delivery.current_year.pluck(:id)[0..1])
      membership = create(:membership,
        basket_size: create(:basket_size, name: "Petit"),
        depot: create(:depot, price: 0),
        basket_price: 21,
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: 1 }
        })

      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        entity: membership,
        annual_fee: 75,
        membership_amount_fraction: 12,
        memberships_amount_description: "Facturation mensuelle #1")
      create(:invoice,
        date: Current.fy_range.min + 1.month,
        member: member,
        entity: membership,
        membership_amount_fraction: 11,
        memberships_amount_description: "Facturation mensuelle #2")

      invoice = create(:invoice,
        id: 127,
        date: Current.fy_range.min + 2.months,
        member: member,
        entity: membership,
        membership_amount_fraction: 10,
        memberships_amount_description: "Facturation mensuelle #3")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence("Panier: Petit PUBLIC 4x 21.00", "84.00")
        .and contain_sequence("Oeufs PUBLIC: 2x 4.80", "9.60")
        .and contain_sequence("Déjà facturé", "-15.60")
        .and contain_sequence("Montant annuel restant", "78.00")
        .and contain_sequence("Facturation mensuelle #3", "* 7.80")
        .and contain_sequence("* TTC, CHF 7.79 HT, CHF 0.01 TVA (0.1%)")
        .and contain_sequence("N° TVA CHE-273.220.900")
      expect(pdf_strings).not_to include "Cotisation annuelle association"
    end

    it "generates invoice with support ammount + baskets_annual_price_change reduc + complements", freeze: "2020-04-01", sidekiq: :inline do
      member = create(:member,
        name: "Alain Reymond",
        address: "Bd Plumhof 6",
        zip: "1800",
        city: "Vevey")
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: "Tomme de Lavaux",
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        started_on: Current.fy_range.min + 2.weeks,
        basket_size: create(:basket_size, name: "Grand"),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        baskets_annual_price_change: -44,
        memberships_basket_complements_attributes: {
          "1" => { basket_complement_id: 2 }
        })

      invoice = create(:invoice,
        id: 123,
        member: member,
        entity: membership,
        annual_fee: 75,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/15.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence("Panier: Grand PUBLIC 2x 30.50", "61.00")
        .and contain_sequence("Ajustement du prix des paniers", "-44.00")
        .and contain_sequence("Tomme de Lavaux PUBLIC: 2x 7.40", "14.80")
        .and contain_sequence("Montant annuel", "31.80", "Facturation annuelle", "* 31.80")
        .and contain_sequence("Cotisation annuelle association", "75.00")
        .and contain_sequence("Total", "106.80")
        .and contain_sequence("* TTC, CHF 31.77 HT, CHF 0.03 TVA (0.1%)")
        .and contain_sequence("N° TVA CHE-273.220.900")
      expect(pdf_strings).not_to include "Montant restant"
    end

    it "generates invoice with support ammount + basket_complements_annual_price_change reduc + complements", freeze: "2020-04-01", sidekiq: :inline do
      member = create(:member,
        name: "Alain Reymond",
        address: "Bd Plumhof 6",
        zip: "1800",
        city: "Vevey")
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: "Tomme de Lavaux",
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        started_on: Current.fy_range.min + 2.weeks,
        basket_size: create(:basket_size, name: "Grand"),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        basket_complements_annual_price_change: -14.15,
        memberships_basket_complements_attributes: {
          "1" => { basket_complement_id: 2 }
        })

      invoice = create(:invoice,
        id: 124,
        member: member,
        entity: membership,
        annual_fee: 75,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/15.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence("Panier: Grand PUBLIC 2x 30.50", "61.00")
        .and contain_sequence("Tomme de Lavaux PUBLIC: 2x 7.40", "14.80")
        .and contain_sequence("Ajustement du prix des compléments", "-14.15")
        .and contain_sequence("Montant annuel", "61.65", "Facturation annuelle", "* 61.65")
        .and contain_sequence("Cotisation annuelle association", "75.00")
        .and contain_sequence("Total", "136.65")
        .and contain_sequence("* TTC, CHF 61.59 HT, CHF 0.06 TVA (0.1%)")
        .and contain_sequence("N° TVA CHE-273.220.900")
      expect(pdf_strings).not_to include "Montant restant"
    end

    it "generates an invoice with support and a previous extra payment covering part of its amount", sidekiq: :inline do
      member = create(:member)
      membership = create(:membership,
        basket_size: create(:basket_size, name: "Grand"),
        basket_price: 30.5)
      create(:payment, amount: 42, member: member)

      invoice = create(:invoice,
        id: 242,
        member: member,
        entity: membership,
        annual_fee: 75,
        memberships_amount_description: "Facturation annuelle")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence("Panier: Grand PUBLIC 4x 30.50", "122.00")
        .and contain_sequence("Montant annuel", "122.00", "Facturation annuelle", "* 122.00")
        .and contain_sequence("Cotisation annuelle association", "75.00")
        .and contain_sequence("Balance", "** -42.00")
        .and contain_sequence("À payer", "155.00")
        .and contain_sequence("* TTC, CHF 121.88 HT, CHF 0.12 TVA (0.1%)")
        .and contain_sequence("N° TVA CHE-273.220.900")
        .and contain_sequence("** Différence entre toutes les factures existantes et tous les paiements effectués au moment de l’émission de cette facture.")
        .and contain_sequence("L’historique de votre facturation est disponible à tout moment sur votre page de membre.")
        expect(pdf_strings).not_to include "Montant restant"
    end

    it "generates an invoice and a previous extra payment covering part of its amount", sidekiq: :inline do
      member = create(:member)
      membership = create(:membership,
        basket_size: create(:basket_size, name: "Grand"),
        basket_price: 30.5)
      create(:payment, amount: 142, member: member)

      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        entity: membership,
        annual_fee: 75,
        membership_amount_fraction: 12,
        memberships_amount_description: "Facturation mensuelle #1")
      invoice = create(:invoice,
        id: 243,
        date: Current.fy_range.min + 1.month,
        member: member,
        entity: membership,
        membership_amount_fraction: 11,
        memberships_amount_description: "Facturation mensuelle #2")

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence("Panier: Grand PUBLIC 4x 30.50", "122.00")
        .and contain_sequence("Déjà facturé", "-10.15")
        .and contain_sequence("Montant annuel restant", "111.85")
        .and contain_sequence("Facturation mensuelle #2", "* 10.15")
        .and contain_sequence("Balance", "** -56.85")
        .and contain_sequence("À payer", "0.00")
        .and contain_sequence("Avoir restant", "46.70")
        .and contain_sequence("* TTC, CHF 10.14 HT, CHF 0.01 TVA (0.1%)")
        .and contain_sequence("N° TVA CHE-273.220.900")
        .and contain_sequence("** Différence entre toutes les factures existantes et tous les paiements effectués au moment de l’émission de cette facture.")
        .and contain_sequence("L’historique de votre facturation est disponible à tout moment sur votre page de membre.")
        .and contain_sequence("CHF", "Montant", "0.00")
      expect(pdf_strings).not_to include "Cotisation annuelle association"
    end
  end

  context "TaPatate! settings" do
    before {
      Current.acp.update!(
        name: "tap",
        logo_url: "https://d2ibcm5tv7rtdh.cloudfront.net/tapatate/logo.jpg",
        share_price: 250,
        shares_number: 1,
        fiscal_year_start_month: 4,
        invoice_info: "Payable dans les 30 jours, avec nos remerciements.",
        invoice_footer: "<b>TaPatate!<b>, c/o Danielle Huser, Dunantstrasse 6, 3006 Bern /// info@tapatate.ch")
    }

    it "generates invoice with positive acp_shares_number", sidekiq: :inline do
      member = create(:member,
        name: "Manuel Rast",
        address: "Donnerbühlweg 31",
        zip: "3012",
        city: "Bern",
        acp_shares_info: "345")
      create(:payment, amount: 75, member: member)
      invoice = create(:invoice,
        id: 301,
        member: member,
        acp_shares_number: 2)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("N° part sociale: 345")
        .and contain_sequence("Acquisition de 2 parts sociales", "500.00")
        .and contain_sequence("Balance", "* -75.00")
        .and contain_sequence("À payer", "425.00")
        .and contain_sequence("* Différence entre toutes les factures existantes et tous les paiements effectués au moment de l’émission de cette facture.")
        .and contain_sequence("L’historique de votre facturation est disponible à tout moment sur votre page de membre.")
    end

    it "generates invoice with negative acp_shares_number", sidekiq: :inline do
      member = create(:member,
        name: "Manuel Rast",
        address: "Donnerbühlweg 31",
        zip: "3012",
        city: "Bern")
      invoice = create(:invoice,
        id: 302,
        member: member,
        acp_shares_number: -2)
      create(:payment, amount: 75, member: member)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("Remboursement de 2 parts sociales", "-500.00")
        .and contain_sequence("Total", "-500.00")
      expect(pdf_strings).not_to include "Avoir"
    end
  end

  context "QR-Code settings" do
    before {
      Current.acp.update!(
        name: "qrcode",
        country_code: "CH",
        iban: "CH4431999123000889012",
        creditor_name: "Robert Schneider AG",
        creditor_address: "Rue du Lac 1268",
        creditor_city: "Biel",
        creditor_zip: "2501",
        invoice_info: "Payable dans les 30 jours, avec nos remerciements.",
        invoice_footer: "<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84",
        share_price: 250,
        shares_number: 1,
        fiscal_year_start_month: 4)
    }
    let(:member) {
      create(:member,
        id: 424242,
        name: "Pia-Maria Rutschmann-Schnyder",
        address: "Grosse Marktgasse 28",
        zip: "9400",
        city: "Rorschach",
        country_code: "CH")
    }

    it "generates invoice with QR Code", sidekiq: :inline do
      invoice = create(:invoice,
        id: 1001,
        member: member,
        acp_shares_number: 5)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("Récépissé")
        .and contain_sequence("Compte / Payable à")
        .and contain_sequence("CH44 3199 9123 0008 8901 2")
        .and contain_sequence("Robert Schneider AG", "Rue du Lac 1268", "2501 Biel")
        .and contain_sequence("Référence", "00 00000 00004 24242 00000 10014")
        .and contain_sequence("Payable par")
        .and contain_sequence("Pia-Maria Rutschmann-Schnyder", "Grosse Marktgasse 28", "9400 Rorschach")
        .and contain_sequence("Monnaie", "CHF")
        .and contain_sequence("Montant", "1 250.00")
        .and contain_sequence("Point de dépôt")
        .and contain_sequence("Section paiement")
        .and contain_sequence("Monnaie", "CHF")
        .and contain_sequence("Montant", "1 250.00")
        .and contain_sequence("Compte / Payable à")
        .and contain_sequence("CH44 3199 9123 0008 8901 2")
        .and contain_sequence("Robert Schneider AG", "Rue du Lac 1268", "2501 Biel")
        .and contain_sequence("Référence", "00 00000 00004 24242 00000 10014")
        .and contain_sequence("Informations supplémentaires", "Facture 1001")
        .and contain_sequence("Payable par")
        .and contain_sequence("Pia-Maria Rutschmann-Schnyder", "Grosse Marktgasse 28", "9400 Rorschach")
    end
  end

  context "France payment section" do
    before {
      Current.acp.update!(
        name: "france",
        country_code: "FR",
        currency_code: "EUR",
        languages: %w[ fr ],
        iban: "FR1420041010050500013M02606",
        sepa_creditor_identifier: nil,
        creditor_name: "Jardin Réunis",
        creditor_address: "1 rue de la Paix",
        creditor_city: "Paris",
        creditor_zip: "75000",
        share_price: 250,
        shares_number: 1)
    }
    let(:member) {
      create(:member,
        id: 424242,
        name: "Jean-Pierre Dupont",
        address: "42 rue de la Liberté",
        city: "Paris",
        zip: "75001",
        country_code: "FR",
        language: "fr",
        iban: nil,
        sepa_mandate_id: nil,
        sepa_mandate_signed_on: nil)
    }

    specify "invoice without SEPA payment section", sidekiq: :inline do
      invoice = create(:invoice,
        id: 8001,
        member: member,
        acp_shares_number: 5)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("Section paiement")
        .and contain_sequence("Montant", "1 250.00 ", "€")
        .and contain_sequence("Compte / Payable à", "Jardin Réunis", "1 rue de la Paix", "75000 Paris")
        .and contain_sequence("IBAN: ", "FR14 2004 1010 0505 0001 3M02 606")
        .and contain_sequence("Numéro de facture / Référence", "8001")
        .and contain_sequence("Payable par", "Jean-Pierre Dupont", "42 rue de la Liberté", "75001 Paris")
    end
  end

  context "German SEPA payment section" do
    before {
      Current.acp.update!(
        name: 'sepa',
        country_code: "DE",
        currency_code: "EUR",
        languages: %w[ de ],
        iban: "DE87200500001234567890",
        sepa_creditor_identifier: "DE98ZZZ09999999999",
        creditor_name: "Gläubiger GmbH",
        creditor_address: "Sonnenallee 1",
        creditor_city: "Hannover",
        creditor_zip: "30159",
        share_price: 250,
        shares_number: 1,
        fiscal_year_start_month: 4)
    }
    let(:member) {
      create(:member,
        id: 424242,
        name: "Pia-Maria Rutschmann-Schnyder",
        address: "Grosse Marktgasse 28",
        zip: "30952",
        city: "Ronnenberg",
        country_code: "DE",
        language: "de",
        iban: "DE21500500009876543210",
        sepa_mandate_id: "42",
        sepa_mandate_signed_on: "2024-03-02")
    }

    specify "invoice with SEPA payment section", sidekiq: :inline do
      invoice = create(:invoice,
        id: 9001,
        member: member,
        acp_shares_number: 5)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("Zahlteil")
        .and contain_sequence("Betrag", "1 250.00 ", "€")
        .and contain_sequence("Konto / Zahlbar an", "Gläubiger GmbH", "Sonnenallee 1", "30159 Hannover")
        .and contain_sequence("IBAN: ", "DE87 2005 0000 1234 5678 90")
        .and contain_sequence("Gla", "̈", "ubiger-ID: ", "DE98ZZZ09999999999")
        .and contain_sequence("Rechnungsnummer / Referenz", "9001")
        .and contain_sequence("Zahlbar durch", "Pia-Maria Rutschmann-Schnyder", "Grosse Marktgasse 28", "30952 Ronnenberg")
        .and contain_sequence("IBAN: ", "DE21 5005 0000 9876 5432 10")
        .and contain_sequence("Mandatsreferenz: ", "42", " (2. März 2024)")
    end
  end

  context "P2R settings" do
    before {
      Current.acp.update!(
        name: "p2r",
        logo_url: "https://d2ibcm5tv7rtdh.cloudfront.net/p2r/logo.jpg",
        fiscal_year_start_month: 1,
        iban: "CH1830123031135810006",
        creditor_name: "Le Panier Bio à 2 Roues",
        creditor_address: "Route de Cery 33",
        creditor_city: "Prilly",
        creditor_zip: "1008",
        country_code: "CH",
        currency_code: "CHF",
        invoice_info: "Payable jusqu'au %{date}, avec nos remerciements.",
        invoice_footer: "<b>Le Panier Bio à 2 Roues</b>, Route de Cery 33, 1008 Prilly /// coordination@p2r.ch, 079 844 43 07",
        shop_invoice_info: "Payable jusqu'au %{date}, avec nos remerciements.")
    }

    it "generates an invoice for a shop order", sidekiq: :inline do
      member = create(:member)
      product = create(:shop_product,
        name: "Courge",
        variants_attributes: {
          "0" => {
            name: "5 kg",
            price: 16
          },
          "1" => {
            name: "10 kg",
            price: 30
          }
        })

      invoice = nil
      order = nil
      travel_to "2021-08-21" do
        delivery = create(:delivery, date: "2021-08-26")
        order = create(:shop_order, :pending,
          member: member,
          delivery: delivery,
          items_attributes: {
            "0" => {
              product_id: product.id,
              product_variant_id: product.variants.first.id,
              quantity: 1
            },
            "1" => {
              product_id: product.id,
              product_variant_id: product.variants.last.id,
              item_price: 29.55,
              quantity: 2
            }
          })
        invoice = order.invoice!
      end

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence("Facture N° #{invoice.id}")
        .and contain_sequence("Commande N° #{order.id}")
        .and contain_sequence("Livraison: 26 août 2021")
        .and contain_sequence("Courge, 5 kg, 1x16.00")
        .and contain_sequence("Courge, 10 kg, 2x29.55")
        .and contain_sequence("Total", "75.10")
        .and contain_sequence("Payable jusqu'au 26 août 2021, avec nos remerciements.")
      expect(pdf_strings).not_to include "Cotisation annuelle association"
    end

    specify "shop order with credit and vat", sidekiq: :inline do
      Current.acp.update!(vat_shop_rate: 2.5, vat_number: "CHE-123.456.789")
      member = create(:member)
      create(:payment, member: member, amount: 12)
      product = create(:shop_product,
        name: "Courge",
        variants_attributes: {
          "0" => {
            name: "5 kg",
            price: 16
          },
          "1" => {
            name: "10 kg",
            price: 30
          }
        })

      invoice = nil
      order = nil
      travel_to "2021-08-21" do
        delivery = create(:delivery, date: "2021-08-26")
        order = create(:shop_order, :pending,
          member: member,
          delivery: delivery,
          items_attributes: {
            "0" => {
              product_id: product.id,
              product_variant_id: product.variants.first.id,
              quantity: 1
            },
            "1" => {
              product_id: product.id,
              product_variant_id: product.variants.last.id,
              item_price: 29.55,
              quantity: 2
            }
          })
      end
      invoice = order.invoice!

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence("Facture N° #{invoice.id}")
        .and contain_sequence("Commande N° #{order.id}")
        .and contain_sequence("Total", "* 75.10")
        .and contain_sequence("Balance", "** -12.00")
        .and contain_sequence("À payer", "63.10")
        .and contain_sequence("* TTC, CHF 73.27 HT, CHF 1.83 TVA (2.5%)")
        .and contain_sequence("N° TVA CHE-123.456.789")
    end
  end

  specify "new member fee invoice", freeze: "2023-01-10", sidekiq: :inline do
    current_acp.update!(
      features: [ "new_member_fee" ],
      new_member_fee_description: "Paniers vides",
      trial_basket_count: 0,
      new_member_fee: 42)

    member = create(:member, :waiting)
    create(:membership, member: member)

    invoice = Billing::InvoicerNewMemberFee.invoice(member)

    pdf_strings = save_pdf_and_return_strings(invoice)
    expect(pdf_strings)
      .to contain_sequence("Facture N° #{invoice.id}")
      .and contain_sequence("Paniers vides", "42.00")
      .and contain_sequence("Total", "42.00")
  end
end

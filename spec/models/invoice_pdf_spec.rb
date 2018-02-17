require 'rails_helper'

describe InvoicePdf do
  def generate_pdf(invoice)
    InvoicePdf.new(invoice, ActionController::Base.new.view_context)
  end

  def save_pdf_and_return_strings(pdf)
    pdf.render_file(
      Rails.root.join("tmp/invoice-#{Current.acp.name}-##{pdf.invoice.id}.pdf"))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  context 'Rage de Vert settings' do
    before {
      Current.acp.update!(
        name: 'rdv',
        ccp: '01-13734-6',
        isr_identity: '00 11041 90802 41000',
        isr_payment_for: "Banque Raiffeisen du Vignoble\n2023 Gorgier",
        isr_in_favor_of: "Association Rage de Vert\nClosel-Bourbon 3\n2075 Thielle",
        invoice_info: 'Payable dans les 30 jours, avec nos remerciements.',
        invoice_footer: '<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84')
    }

    it 'generates invoice with all settings and member name and address' do
      member = create(:member,
        name: 'John Doe',
        address: 'unknown str. 42',
        zip: '0123',
        city: 'Nowhere')
      invoice = create(:invoice, :support, id: 706, member: member)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include 'Facture N° 706'
      expect(pdf_strings).to include 'John Doe'
      expect(pdf_strings).to include 'Unknown str. 42'
      expect(pdf_strings).to include "0123 Nowhere"
      expect(pdf_strings).to include 'Banque Raiffeisen du Vignoble'
      expect(pdf_strings).to include '2023 Gorgier'
      expect(pdf_strings).to include 'Association Rage de Vert'
      expect(pdf_strings).to include 'Closel-Bourbon 3'
      expect(pdf_strings).to include '2075 Thielle'
      expect(pdf_strings).to include 'N° facture: 706'
      expect(pdf_strings).to include '01-13734-6'
    end

    it 'generates invoice with only support amount' do
      invoice = create(:invoice, :support, id: 807, support_amount: 42)
      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).not_to include 'Montant annuel'
      expect(pdf_strings).to include 'Cotisation annuelle association'
      expect(pdf_strings).to include '42.00'
      expect(pdf_strings).to include '0100000042007>001104190802410000000008070+ 01137346>'
    end

    it 'generates invoice with support amount + annual membership' do
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0))
      invoice = create(:invoice,
        id: 4,
        support_amount: 42,
        memberships_amount_description: 'Montant annuel',
        membership: membership)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include (/Abonnement du 01\.01\.20\d\d au 31\.12\.20\d\d \(40 livraisons\)/)
      expect(pdf_strings).to include 'Paniers: 40 x 33.25'
      expect(pdf_strings).to include "1'330.00"
      expect(pdf_strings).not_to include 'Demi-journées de travail'
      expect(pdf_strings).to include 'Cotisation annuelle association'
      expect(pdf_strings).to include '42.00'
      expect(pdf_strings).to include 'Montant annuel'
      expect(pdf_strings).not_to include 'Montant annuel restant'
      expect(pdf_strings).to include "1'330.00"
      expect(pdf_strings).to include "1'372.00"
      expect(pdf_strings).to include '0100001372007>001104190802410000000000048+ 01137346>'
    end

    it 'generates invoice with support ammount + annual membership + halfday_works reduc' do
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0),
        annual_halfday_works: 8,
        halfday_works_annual_price: -330.50)
      invoice = create(:invoice,
        id: 7,
        support_amount: 30,
        memberships_amount_description: 'Montant annuel',
        membership: membership)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include(/Abonnement du 01\.01\.20\d\d au 31\.12\.20\d\d \(40 livraisons\)/)
      expect(pdf_strings).to include 'Paniers: 40 x 33.25'
      expect(pdf_strings).to include "1'330.00"
      expect(pdf_strings).to include 'Réduction pour 6 demi-journées de travail supplémentaires'
      expect(pdf_strings).to include '- 330.50'
      expect(pdf_strings).to include 'Cotisation annuelle association'
      expect(pdf_strings).to include '30.00'
      expect(pdf_strings).to include 'Montant annuel'
      expect(pdf_strings).not_to include 'Montant restant'
      expect(pdf_strings).to include "999.50"
      expect(pdf_strings).to include "1'029.50"
      expect(pdf_strings).to include "0100001029509>001104190802410000000000077+ 01137346>"
    end

    it 'generates invoice with support ammount + quarter membership' do
      member = create(:member, billing_interval: 'quarterly')
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 2))
      invoice =  create(:invoice,
        id: 8,
        member: member,
        support_amount: 30,
        membership_amount_fraction: 4,
        memberships_amount_description: 'Montant trimestriel #1',
        membership: membership)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include(/Abonnement du 01\.01\.20\d\d au 31\.12\.20\d\d \(40 livraisons\)/)
      expect(pdf_strings).to include 'Paniers: 40 x 33.25'
      expect(pdf_strings).to include "1'330.00"
      expect(pdf_strings).to include 'Distributions: 40 x 2.00'
      expect(pdf_strings).to include '80.00'
      expect(pdf_strings).not_to include 'Demi-journées de travail'
      expect(pdf_strings).to include 'Cotisation annuelle association'
      expect(pdf_strings).to include '30.00'
      expect(pdf_strings).to include 'Montant trimestriel #1'
      expect(pdf_strings).to include '352.50'
      expect(pdf_strings).to include '382.50'
      expect(pdf_strings).to include '0100000382503>001104190802410000000000085+ 01137346>'
    end

    it 'generates invoice with quarter menbership and paid amount' do
      member = create(:member, billing_interval: 'quarterly')
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0))
      create(:invoice,
        date: Time.current.beginning_of_year,
        member: member,
        membership_amount_fraction: 4,
        memberships_amount_description: 'Montant trimestriel #1',
        membership: membership)
      create(:invoice,
        date: Time.current.beginning_of_year + 4.months,
        member: member,
        membership_amount_fraction: 3,
        memberships_amount_description: 'Montant trimestriel #2',
        membership: membership)
      invoice = create(:invoice,
        id: 11,
        date: Time.current.beginning_of_year + 8.months,
        member: member,
        membership_amount_fraction: 2,
        memberships_amount_description: 'Montant trimestriel #3',
        membership: membership)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).not_to include 'Cotisation annuelle association'
      expect(pdf_strings).to include 'Montant trimestriel #3'
      expect(pdf_strings).to include 'Paniers: 40 x 33.25'
      expect(pdf_strings).to include "1'330.00"
      expect(pdf_strings).to include '- 665.00'
      expect(pdf_strings).to include '665.00'
      expect(pdf_strings).to include '332.50'
      expect(pdf_strings).to include '0100000332508>001104190802410000000000112+ 01137346>'
    end
  end

  context 'Lumiere des Champs settings' do
    before {
      set_acp_logo('ldc_logo.jpg')
      Current.acp.update!(
        name: 'ldc',
        fiscal_year_start_month: 4,
        summer_month_range: 4..9,
        ccp: '01-9252-0',
        isr_identity: '800250',
        isr_payment_for: "Banque Alternative Suisse SA\n4601 Olten",
        isr_in_favor_of: "Association Lumière des Champs\nBd Paderewski 32\n1800 Vevey",
        invoice_info: 'Payable dans les 30 jours, avec nos remerciements.',
        invoice_footer: '<b>Association Lumière des Champs</b>, Bd Paderewski 32, 1800 Vevey – comptabilite@lumiere-des-champs.ch')
      start_day = Current.fy_range.min.end_of_week + 2.months
      8.times.each do |i|
        Delivery.create(date: start_day)
        start_day += 1.month
      end
    }

    it 'generates invoice with support amount + complements + annual membership' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement,
        id: 1,
        price: 4.8,
        delivery_ids: Delivery.current_year.pluck(:id)[0..23])
      create(:basket_complement,
        id: 2,
        price: 7.4,
        delivery_ids: Delivery.current_year.pluck(:id)[24..48])
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0),
        basket_price: 30.5,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 },
          '1' => { basket_complement_id: 2 }
        })
      invoice = create(:invoice,
        id: 122,
        support_amount: 75,
        memberships_amount_description: 'Montant annuel',
        membership: membership,
        member: member)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include(/Abonnement du 01\.04\.20\d\d au 31\.03\.20\d\d \(48 livraisons\)/)
      expect(pdf_strings).to include 'Paniers: 48 x 30.50'
      expect(pdf_strings).to include "1'464.00"
      expect(pdf_strings).to include "Compléments: 24 x 4.80 + 24 x 7.40"
      expect(pdf_strings).to include '292.80'
      expect(pdf_strings).not_to include 'Montant restant'
      expect(pdf_strings).to include 'Montant annuel'
      expect(pdf_strings).to include "1'756.80"
      expect(pdf_strings).to include 'Cotisation annuelle association'
      expect(pdf_strings).to include '75.00'
      expect(pdf_strings).to include "1'831.80"
      expect(pdf_strings).to include '0100001831806>800250000000000000000001221+ 0192520>'
    end

    it 'generates invoice with support ammount + four month membership + winter basket' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0),
        basket_price: 30.5,
        seasons: %w[winter])
      create(:invoice,
        support_amount: 75,
        date: Current.fy_range.min,
        membership_amount_fraction: 3,
        memberships_amount_description: 'Montant quadrimestriel #1',
        membership: membership,
        member: member)
      invoice = create(:invoice,
        id: 125,
        date: Current.fy_range.min + 4.month,
        membership_amount_fraction: 2,
        memberships_amount_description: 'Montant quadrimestriel #2',
        membership: membership,
        member: member)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include(/Abonnement du 01\.04\.20\d\d au 31\.03\.20\d\d \(48 livraisons\)/)
      expect(pdf_strings).to include 'Paniers: 22 x 30.50'
      expect(pdf_strings).to include '671.00'
      expect(pdf_strings).to include '- 223.65'
      expect(pdf_strings).to include 'Montant annuel restant'
      expect(pdf_strings).to include '447.35'
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
      expect(pdf_strings).to include 'Montant quadrimestriel #2'
      expect(pdf_strings).to include '223.70'
      expect(pdf_strings).to include '0100000223709>800250000000000000000001252+ 0192520>'
    end

    it 'generates invoice with mensual membership + complements' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement,
        id: 1,
        price: 4.8,
        delivery_ids: Delivery.current_year.pluck(:id)[0..23])
      membership = create(:membership,
        basket_size: create(:basket_size, :small),
        distribution: create(:distribution, price: 0),
        basket_price: 21,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      create(:invoice,
        support_amount: 75,
        date: Current.fy_range.min,
        membership_amount_fraction: 12,
        memberships_amount_description: 'Montant mensuel #1',
        membership: membership,
        member: member)
      create(:invoice,
        date: Current.fy_range.min + 1.month,
        membership_amount_fraction: 11,
        memberships_amount_description: 'Montant mensuel #2',
        membership: membership,
        member: member)

      invoice = create(:invoice,
        id: 127,
        date: Current.fy_range.min + 2.months,
        membership_amount_fraction: 10,
        memberships_amount_description: 'Montant mensuel #3',
        membership: membership,
        member: member)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include(/Abonnement du 01\.04\.20\d\d au 31\.03\.20\d\d \(48 livraisons\)/)
      expect(pdf_strings).to include 'Paniers: 48 x 21.00'
      expect(pdf_strings).to include "1'008.00"
      expect(pdf_strings).to include "Compléments: 24 x 4.80"
      expect(pdf_strings).to include '115.20'
      expect(pdf_strings).to include '- 187.20'
      expect(pdf_strings).to include 'Montant annuel restant'
      expect(pdf_strings).to include '936.00'
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
      expect(pdf_strings).to include 'Montant mensuel #3'
      expect(pdf_strings).to include '93.60'
      expect(pdf_strings).to include '0100000093604>800250000000000000000001273+ 0192520>'
    end

    it 'generates invoice with support ammount + baskets_annual_price_change reduc + complements' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement,
        id: 2,
        price: 7.4,
        delivery_ids: Delivery.current_year.pluck(:id)[24..48])
      membership = create(:membership,
        started_on: Current.fy_range.min + 5.months,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0),
        basket_price: 30.5,
        baskets_annual_price_change: -44,
        memberships_basket_complements_attributes: {
          '1' => { basket_complement_id: 2 }
        })

      invoice = create(:invoice,
        id: 123,
        support_amount: 75,
        memberships_amount_description: 'Montant annuel',
        membership: membership,
        member: member)

      pdf = generate_pdf(invoice)
      pdf_strings = save_pdf_and_return_strings(pdf)

      expect(pdf_strings).to include(/Abonnement du 01\.09\.20\d\d au 31\.03\.20\d\d \(27 livraisons\)/)
      expect(pdf_strings).to include 'Paniers: 27 x 30.50'
      expect(pdf_strings).to include '823.50'
      expect(pdf_strings).to include 'Ajustement du prix des paniers'
      expect(pdf_strings).to include '- 44.00'
      expect(pdf_strings).to include "Compléments: 24 x 7.40"
      expect(pdf_strings).to include '177.60'
      expect(pdf_strings).not_to include 'Montant restant'
      expect(pdf_strings).to include '957.10'
      expect(pdf_strings).to include 'Cotisation annuelle association'
      expect(pdf_strings).to include '75.00'
      expect(pdf_strings).to include 'Montant annuel'
      expect(pdf_strings).to include "1'032.10"
      expect(pdf_strings).to include '0100001032108>800250000000000000000001236+ 0192520>'
    end
  end
end

require 'rails_helper'

describe PDF::Invoice do
  def save_pdf_and_return_strings(invoice)
    pdf = PDF::Invoice.new(invoice)
    pdf_path = "tmp/invoice-#{Current.acp.name}-##{pdf.invoice.id}.pdf"
    pdf.render_file(Rails.root.join(pdf_path))
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

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include('Facture N° 706')
        .and contain_sequence('John Doe', 'Unknown str. 42', '0123 Nowhere')
        .and contain_sequence('Banque Raiffeisen du Vignoble', '2023 Gorgier')
        .and contain_sequence('Association Rage de Vert', 'Closel-Bourbon 3', '2075 Thielle')
        .and include('N° facture: 706')
        .and include('01-13734-6')
    end

    it 'generates invoice with only support amount' do
      invoice = create(:invoice, :support, id: 807, support_amount: 42)
      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence('Cotisation annuelle association', '42.00')
        .and include('0100000042007>001104190802410000000008070+ 01137346>')
      expect(pdf_strings).not_to include('Facturation anuelle')
    end

    it 'generates invoice with support amount + annual membership' do
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0))
      invoice = create(:invoice,
        id: 4,
        object: membership,
        support_amount: 42,
        memberships_amount_description: 'Facturation anuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01\.01\.20\d\d au 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Abondance 40x 33.25', "1'330.00")
        .and contain_sequence('Montant annuel', "1'330.00", 'Facturation anuelle', "1'330.00")
        .and contain_sequence('Cotisation annuelle association', '42.00')
        .and contain_sequence('Total', "1'372.00")
        .and include '0100001372007>001104190802410000000000048+ 01137346>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support ammount + annual membership + halfday_works reduc' do
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0),
        annual_halfday_works: 8,
        halfday_works_annual_price: -330.50)
      invoice = create(:invoice,
        id: 7,
        object: membership,
        support_amount: 30,
        memberships_amount_description: 'Facturation anuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01\.01\.20\d\d au 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Abondance 40x 33.25', "1'330.00")
        .and contain_sequence('Réduction pour 6 demi-journées supplémentaires', '- 330.50')
        .and contain_sequence('Montant annuel', "999.50", 'Facturation anuelle', "999.50")
        .and contain_sequence('Cotisation annuelle association', '30.00')
        .and contain_sequence('Total', "1'029.50")
        .and include '0100001029509>001104190802410000000000077+ 01137346>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support ammount + quarter membership' do
      member = create(:member, billing_year_division: 4)
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :small, price: '23.125'),
        distribution: create(:distribution, name: 'La Chaux-de-Fonds', price: 4))
      invoice =  create(:invoice,
        id: 8,
        member: member,
        object: membership,
        support_amount: 30,
        membership_amount_fraction: 4,
        memberships_amount_description: 'Montant trimestriel #1')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01\.01\.20\d\d au 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Eveil 40x 23.125', '925.00')
        .and contain_sequence('Distribution: La Chaux-de-Fonds 40x 4.00', '160.00')
        .and contain_sequence('Montant annuel', "1'085.00")
        .and contain_sequence('Montant trimestriel #1', '271.25')
        .and contain_sequence('Cotisation annuelle association', '30.00')
        .and contain_sequence('Total', '301.25')
        .and include '0100000301256>001104190802410000000000085+ 01137346>'
    end

    it 'generates invoice with quarter menbership and paid amount' do
      member = create(:member, billing_year_division: 4)
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :big),
        distribution: create(:distribution, price: 0))
      create(:invoice,
        date: Time.current.beginning_of_year,
        member: member,
        object: membership,
        membership_amount_fraction: 4,
        memberships_amount_description: 'Facturation trimestrielle #1')
      create(:invoice,
        date: Time.current.beginning_of_year + 4.months,
        member: member,
        object: membership,
        membership_amount_fraction: 3,
        memberships_amount_description: 'Facturation trimestrielle #2')
      invoice = create(:invoice,
        id: 11,
        date: Time.current.beginning_of_year + 8.months,
        member: member,
        object: membership,
        membership_amount_fraction: 2,
        memberships_amount_description: 'Facturation trimestrielle #3')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01\.01\.20\d\d au 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Abondance 40x 33.25', "1'330.00",)
        .and contain_sequence('Déjà facturé', '- 665.00')
        .and contain_sequence('Montant annuel restant', '665.00')
        .and contain_sequence('Facturation trimestrielle #3', '332.50')
        .and include('0100000332508>001104190802410000000000112+ 01137346>')
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end

    it 'generates invoice with HalfdayParticipation object' do
      halfday = create(:halfday, date: '2018-3-4')
      rejected_participation = create(:halfday_participation, :rejected,
        halfday: halfday)
      invoice = create(:invoice,
        id: 2001,
        date: '2018-4-5',
        object: rejected_participation,
        amount: 120,
        paid_missing_halfday_works: 2)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence('½ ', 'Journée du 4 mars 2018 non-effectuée (2 participants)', '120.00')
        .and contain_sequence('Total', '120.00')
        .and include('0100000120000>001104190802410000000020015+ 01137346>')
    end

    it 'generates invoice with HalfdayParticipation type (one participant)' do
      invoice = create(:invoice,
        id: 2002,
        date: '2018-4-5',
        object_type: 'HalfdayParticipation',
        amount: 60,
        paid_missing_halfday_works: 1)

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence('½ ', 'Journée non-effectuée', '60.00')
        .and contain_sequence('Total', '60.00')
        .and include('0100000060004>001104190802410000000020020+ 01137346>')
    end
    it 'generates invoice with HalfdayParticipation type (many participants)' do
      invoice = create(:invoice,
        id: 2003,
        date: '2018-4-5',
        object_type: 'HalfdayParticipation',
        amount: 180,
        paid_missing_halfday_works: 3)

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence('3 ', '½ ', 'journées non-effectuées', '180.00')
        .and contain_sequence('Total', '180.00')
        .and include('0100000180005>001104190802410000000020031+ 01137346>')
    end
  end

  context 'Lumiere des Champs settings' do
    before {
      set_acp_logo('ldc_logo.jpg')
      Current.acp.update!(
        name: 'ldc',
        fiscal_year_start_month: 4,
        summer_month_range: 4..9,
        vat_membership_rate: 0.1,
        vat_number: 'CHE-273.220.900',
        ccp: '01-9252-0',
        isr_identity: '800250',
        isr_payment_for: "Banque Alternative Suisse SA\n4601 Olten",
        isr_in_favor_of: "Association Lumière des Champs\nBd Paderewski 28\n1800 Vevey",
        invoice_info: 'Payable dans les 30 jours, avec nos remerciements.',
        invoice_footer: '<b>Association Lumière des Champs</b>, Bd Paderewski 28, 1800 Vevey – comptabilite@lumiere-des-champs.ch')
      create_deliveries(48)
    }

    it 'generates invoice with support amount + complements + annual membership' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement,
        id: 1,
        name: 'Oeufs',
        price: 4.8,
        delivery_ids: Delivery.current_year.pluck(:id)[0..23])
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id)[24..48])
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        distribution: create(:distribution, price: 0),
        basket_price: 30.5,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 },
          '1' => { basket_complement_id: 2 }
        })
      invoice = create(:invoice,
        id: 122,
        member: member,
        object: membership,
        support_amount: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/Période du 01.04.20\d\d au 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand 48x 30.50', "1'464.00")
        .and contain_sequence('Oeufs 24x 4.80', "115.20")
        .and contain_sequence('Tomme de Lavaux 24x 7.40', "177.60")
        .and contain_sequence('Montant annuel', "1'756.80", 'Facturation annuelle', "* 1'756.80")
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Total', "1'831.80")
        .and contain_sequence("* TTC, CHF 1'755.04 HT, CHF 1.76 TVA (0.1%)")
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100001831806>800250000000000000000001221+ 0192520>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support ammount + four month membership + winter basket' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        distribution: create(:distribution, price: 0),
        basket_price: 30.5,
        seasons: %w[winter])
      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        object: membership,
        support_amount: 75,
        membership_amount_fraction: 3,
        memberships_amount_description: 'Facturation quadrimestrielle #1')
      invoice = create(:invoice,
        id: 125,
        date: Current.fy_range.min + 4.month,
        member: member,
        object: membership,
        membership_amount_fraction: 2,
        memberships_amount_description: 'Facturation quadrimestrielle #2')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01.04.20\d\d au 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand 22x 30.50', '671.00')
        .and contain_sequence('Déjà facturé', '- 223.65')
        .and contain_sequence('Montant annuel restant', '447.35')
        .and contain_sequence('Facturation quadrimestrielle #2', "* 223.70")
        .and contain_sequence('* TTC, CHF 223.48 HT, CHF 0.22 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000223709>800250000000000000000001252+ 0192520>'
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end

    it 'generates invoice with mensual membership + complements' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement,
        id: 1,
        name: 'Oeufs',
        price: 4.8,
        delivery_ids: Delivery.current_year.pluck(:id)[0..23])
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Petit'),
        distribution: create(:distribution, price: 0),
        basket_price: 21,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        object: membership,
        support_amount: 75,
        membership_amount_fraction: 12,
        memberships_amount_description: 'Facturation mensuelle #1')
      create(:invoice,
        date: Current.fy_range.min + 1.month,
        member: member,
        object: membership,
        membership_amount_fraction: 11,
        memberships_amount_description: 'Facturation mensuelle #2')

      invoice = create(:invoice,
        id: 127,
        date: Current.fy_range.min + 2.months,
        member: member,
        object: membership,
        membership_amount_fraction: 10,
        memberships_amount_description: 'Facturation mensuelle #3')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01.04.20\d\d au 31.03.20\d\d/)
        .and contain_sequence('Panier: Petit 48x 21.00', "1'008.00")
        .and contain_sequence('Oeufs 24x 4.80', "115.20")
        .and contain_sequence('Déjà facturé', '- 187.20')
        .and contain_sequence('Montant annuel restant', '936.00')
        .and contain_sequence('Facturation mensuelle #3', "* 93.60")
        .and contain_sequence('* TTC, CHF 93.51 HT, CHF 0.09 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000093604>800250000000000000000001273+ 0192520>'
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
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
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id)[24..48])
      membership = create(:membership,
        started_on: Current.fy_range.min + 5.months,
        basket_size: create(:basket_size, name: 'Grand'),
        distribution: create(:distribution, price: 0),
        basket_price: 30.5,
        baskets_annual_price_change: -44,
        memberships_basket_complements_attributes: {
          '1' => { basket_complement_id: 2 }
        })

      invoice = create(:invoice,
        id: 123,
        member: member,
        object: membership,
        support_amount: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01.09.20\d\d au 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand 26x 30.50', '793.00')
        .and contain_sequence('Ajustement du prix des paniers', '- 44.00')
        .and contain_sequence('Tomme de Lavaux 24x 7.40', '177.60')
        .and contain_sequence('Montant annuel', '926.60', 'Facturation annuelle', '* 926.60')
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Total', "1'001.60")
        .and contain_sequence('* TTC, CHF 925.67 HT, CHF 0.93 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100001001604>800250000000000000000001236+ 0192520>'
      expect(pdf_strings).not_to include 'Montant restant'
    end

    it 'generates an invoice with support and a previous extra payment covering part of its amount' do
      member = create(:member)
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        basket_price: 30.5)
      create(:payment, amount: 242, member: member)

      invoice = create(:invoice,
        id: 242,
        member: member,
        object: membership,
        support_amount: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/Période du 01.04.20\d\d au 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand 48x 30.50', "1'464.00")
        .and contain_sequence('Montant annuel', "1'464.00", 'Facturation annuelle', "* 1'464.00")
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Avoir', "- 242.00")
        .and contain_sequence("À payer", "1'297.00")
        .and contain_sequence("* TTC, CHF 1'462.54 HT, CHF 1.46 TVA (0.1%)")
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100001297005>800250000000000000000002428+ 0192520>'
        expect(pdf_strings).not_to include 'Montant restant'
    end

    it 'generates an invoice and a previous extra payment covering part of its amount' do
      member = create(:member)
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        basket_price: 30.5)
      create(:payment, amount: 444, member: member)

      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        object: membership,
        support_amount: 75,
        membership_amount_fraction: 12,
        memberships_amount_description: 'Facturation mensuelle #1')
      invoice = create(:invoice,
        id: 243,
        date: Current.fy_range.min + 1.month,
        member: member,
        object: membership,
        membership_amount_fraction: 11,
        memberships_amount_description: 'Facturation mensuelle #2')

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include(/Période du 01.04.20\d\d au 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand 48x 30.50', "1'464.00")
        .and contain_sequence('Déjà facturé', '- 122.00')
        .and contain_sequence('Montant annuel restant', "1'342.00")
        .and contain_sequence('Facturation mensuelle #2', '* 122.00')
        .and contain_sequence('Avoir', '- 247.00')
        .and contain_sequence("À payer", '0.00')
        .and contain_sequence('* TTC, CHF 121.88 HT, CHF 0.12 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000000005>800250000000000000000002433+ 0192520>'
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end
  end
end

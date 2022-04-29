require 'rails_helper'

describe PDF::Invoice do
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
        address: 'Unknown Str. 42',
        zip: '0123',
        city: 'Nowhere')
      invoice = create(:invoice, :annual_fee, id: 706, member: member)

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to include('Facture N° 706')
        .and contain_sequence('John Doe', 'Unknown Str. 42', '0123 Nowhere')
        .and contain_sequence('Banque Raiffeisen du Vignoble', '2023 Gorgier')
        .and contain_sequence('Association Rage de Vert', 'Closel-Bourbon 3', '2075 Thielle')
        .and include('N° Facture: 706')
        .and include('01-13734-6')
    end

    it 'generates invoice with only annual_fee amount' do
      invoice = create(:invoice, :annual_fee, id: 807, annual_fee: 42)
      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence('Cotisation annuelle association', '42.00')
        .and include('0100000042007>001104190802410000000008070+ 010137346>')
      expect(pdf_strings).not_to include('Facturation annuelle')
    end

    it 'generates invoice with annual_fee amount + annual membership' do
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        deliveries_count: 2)
      invoice = create(:invoice,
        id: 4,
        object: membership,
        annual_fee: 42,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Abondance PUBLIC 2x 33.25', "66.50")
        .and contain_sequence('Montant annuel', "66.50", 'Facturation annuelle', "66.50")
        .and contain_sequence('Cotisation annuelle association', '42.00')
        .and contain_sequence('Total', "108.50")
        .and include '0100000108507>001104190802410000000000048+ 010137346>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support ammount + annual membership + activity_participations reduc' do
      membership = create(:membership,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        activity_participations_demanded_annualy: 8,
        activity_participations_annual_price_change: -20.50,
        deliveries_count: 2)
      invoice = create(:invoice,
        id: 7,
        object: membership,
        annual_fee: 30,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Abondance PUBLIC 2x 33.25', "66.50")
        .and contain_sequence('Réduction pour 6 ', '½ ', 'journées supplémentaires', '-20.50')
        .and contain_sequence('Montant annuel', "46.00", 'Facturation annuelle', "46.00")
        .and contain_sequence('Cotisation annuelle association', '30.00')
        .and contain_sequence('Total', "76.00")
        .and include '0100000076007>001104190802410000000000077+ 010137346>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support ammount + quarter membership' do
      member = create(:member, billing_year_division: 4)
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :small, price: '23.125'),
        depot: create(:depot, name: 'La Chaux-de-Fonds', price: 4),
        deliveries_count: 2)
      invoice =  create(:invoice,
        id: 8,
        member: member,
        object: membership,
        annual_fee: 30,
        membership_amount_fraction: 4,
        memberships_amount_description: 'Montant trimestriel #1')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Eveil PUBLIC 2x 23.125', '46.25')
        .and contain_sequence('Dépôt: La Chaux-de-Fonds PUBLIC 2x 4.00', '8.00')
        .and contain_sequence('Montant annuel', "54.25")
        .and contain_sequence('Montant trimestriel #1', '13.55')
        .and contain_sequence('Cotisation annuelle association', '30.00')
        .and contain_sequence('Total', '43.55')
        .and include '0100000043552>001104190802410000000000085+ 010137346>'
    end

    it 'generates invoice with membership basket_price_extra' do
      Current.acp.update!(
        features: ['basket_price_extra'],
        basket_price_extra_title: 'Prix Extra',
        basket_price_extra_public_title: 'Cotistation Solidaire')
      membership = create(:membership,
        basket_price_extra: 4,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        deliveries_count: 2)
      invoice = create(:invoice,
        id: 4,
        object: membership,
        annual_fee: 42,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Abondance PUBLIC 2x 33.25', "66.50")
        .and contain_sequence('Cotistation Solidaire 2x 4.00', "8.00")
        .and contain_sequence('Cotisation annuelle association', '42.00')
        .and contain_sequence('Total', "116.50")
    end

    it 'generates invoice with quarter menbership and paid amount' do
      member = create(:member, billing_year_division: 4)
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, :big),
        depot: create(:depot, price: 0),
        deliveries_count: 2)
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
        id: 1001,
        date: Time.current.beginning_of_year + 8.months,
        member: member,
        object: membership,
        membership_amount_fraction: 2,
        memberships_amount_description: 'Facturation trimestrielle #3')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01\.01\.20\d\d – 31\.12\.20\d\d/)
        .and contain_sequence('Panier: Abondance PUBLIC 2x 33.25', "66.50",)
        .and contain_sequence('Déjà facturé', '-33.25')
        .and contain_sequence('Montant annuel restant', '33.25')
        .and contain_sequence('Facturation trimestrielle #3', '16.65')
        .and include('0100000016653>001104190802410000000010019+ 010137346>')
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end

    it 'generates invoice with ActivityParticipation object' do
      activity = create(:activity, date: '2018-3-4')
      rejected_participation = create(:activity_participation, :rejected,
        activity: activity)
      invoice = create(:invoice,
        id: 2001,
        date: '2018-4-5',
        object: rejected_participation,
        paid_missing_activity_participations: 2)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence('½ ', 'journée du 4 mars 2018 non-effectuée (2 participants)', '120.00')
        .and contain_sequence('Total', '120.00')
        .and include('0100000120000>001104190802410000000020015+ 010137346>')
    end

    it 'generates invoice with ActivityParticipation type (one participant)' do
      invoice = create(:invoice,
        id: 2002,
        date: '2018-4-5',
        paid_missing_activity_participations: 1)

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence('½ ', 'journée non-effectuée', '60.00')
        .and contain_sequence('Total', '60.00')
        .and include('0100000060004>001104190802410000000020020+ 010137346>')
    end

    it 'generates invoice with ActivityParticipation type (many participants)' do
      invoice = create(:invoice,
        id: 2003,
        date: '2018-4-5',
        paid_missing_activity_participations: 3,
        activity_price: 60)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence('3 ', '½ ', 'journées non effectuées', '180.00')
        .and contain_sequence('Total', '180.00')
        .and include('0100000180005>001104190802410000000020031+ 010137346>')
    end

    it 'generates an invoice with items' do
      invoice = create(:invoice,
        id: 2010,
        date: '2018-11-01',
        items_attributes: {
          '0' => { description: 'Un truc cool pas cher', amount: 10 },
          '1' => { description: 'Un truc cool pluc cher', amount: 32 }
        })

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence('Un truc cool pas cher', '10.00')
        .and contain_sequence('Un truc cool pluc cher', '32.00')
        .and contain_sequence('Total', '42.00')
        .and include('0100000042007>001104190802410000000020106+ 010137346>')
    end
  end

  context 'Lumiere des Champs settings' do
    before {
      Current.acp.update!(
        name: 'ldc',
        logo_url: 'https://d2ibcm5tv7rtdh.cloudfront.net/lumieredeschamps/logo.jpg',
        fiscal_year_start_month: 4,
        vat_membership_rate: 0.1,
        vat_number: 'CHE-273.220.900',
        ccp: '01-9252-0',
        isr_identity: '800250',
        isr_payment_for: "Banque Alternative Suisse SA\n4601 Olten",
        isr_in_favor_of: "Association Lumière des Champs\nBd Paderewski 28\n1800 Vevey",
        invoice_info: 'Payable dans les 30 jours, avec nos remerciements.',
        invoice_footer: '<b>Association Lumière des Champs</b>, Bd Paderewski 28, 1800 Vevey – comptabilite@lumiere-des-champs.ch',
        features: ['group_buying'],
        group_buying_invoice_info: "Payable jusqu'au %{date}, avec nos remerciements.")
      create_deliveries(4)
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
        delivery_ids: Delivery.current_year.pluck(:id)[0..1])
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 },
          '1' => { basket_complement_id: 2 }
        })
      invoice = create(:invoice,
        id: 122,
        member: member,
        object: membership,
        annual_fee: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand PUBLIC 4x 30.50', "122.00")
        .and contain_sequence('Oeufs PUBLIC 2x 4.80', "9.60")
        .and contain_sequence('Tomme de Lavaux PUBLIC 2x 7.40', "14.80")
        .and contain_sequence('Montant annuel', "146.40", 'Facturation annuelle', "* 146.40")
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Total', "221.40")
        .and contain_sequence("* TTC, CHF 146.25 HT, CHF 0.15 TVA (0.1%)")
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000221408>800250000000000000000001221+ 010092520>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support amount + complements with annual price type + annual membership' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement, :annual_price_type,
        id: 1,
        name: "Les Voisins d'abord",
        price: 200)
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 2 },
          '1' => { basket_complement_id: 2 }
        })
      invoice = create(:invoice,
        id: 1220,
        member: member,
        object: membership,
        annual_fee: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand PUBLIC 4x 30.50', "122.00")
        .and contain_sequence("Les Voisins d'abord PUBLIC 2x 200.00", "400.00")
        .and contain_sequence('Tomme de Lavaux PUBLIC 2x 7.40', "14.80")
        .and contain_sequence('Montant annuel', "536.80", 'Facturation annuelle', "* 536.80")
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Total', "611.80")
        .and contain_sequence("* TTC, CHF 536.26 HT, CHF 0.54 TVA (0.1%)")
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000611805>800250000000000000000012205+ 010092520>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support amount + complements with annual price type + annual membership (no absences billed)', freeze: '2019-04-01' do
      Current.acp.update!(absences_billed: false)
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement, :annual_price_type,
        id: 1,
        name: "Les Voisins d'abord",
        price: 200)
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        member: member,
        basket_size: create(:basket_size, name: 'Grand'),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 2 },
          '1' => { basket_complement_id: 2 }
        })

      create(:absence,
        admin: create(:admin),
        member: member.reload,
        started_on: Delivery.last.date - 1.day,
        ended_on: Delivery.last.date + 1.day)
      invoice = create(:invoice,
        id: 1220,
        member: member,
        object: membership.reload,
        annual_fee: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence('01.04.2019 – 31.03.2020')
        .and contain_sequence('Panier: Grand PUBLIC 3x 30.50', "91.50")
        .and contain_sequence("Les Voisins d'abord PUBLIC 2x 200.00", '400.00')
        .and contain_sequence('Tomme de Lavaux PUBLIC 1x 7.40', '7.40')
        .and contain_sequence('Montant annuel', "498.90", 'Facturation annuelle', "* 498.90")
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Total', "573.90")
        .and contain_sequence("* TTC, CHF 498.40 HT, CHF 0.50 TVA (0.1%)")
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000573906>800250000000000000000012205+ 010092520>'
      expect(pdf_strings).not_to include 'Montant annuel restant'
    end

    it 'generates invoice with support ammount + four month membership + winter basket', freeze: '2019-04-01' do
      create(:delivery, date: '2019-10-01')
      winter_dc = create(:deliveries_cycle, months: [1,2,3,10,11,12])
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        depot: create(:depot, price: 0, deliveries_cycles: [winter_dc]),
        basket_price: 30.5)
      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        object: membership,
        annual_fee: 75,
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
        .to contain_sequence('01.04.2019 – 31.03.2020')
        .and contain_sequence('Panier: Grand PUBLIC 1x 30.50', '30.50')
        .and contain_sequence('Déjà facturé', '-10.15')
        .and contain_sequence('Montant annuel restant', '20.35')
        .and contain_sequence('Facturation quadrimestrielle #2', '* 10.20')
        .and contain_sequence('* TTC, CHF 10.19 HT, CHF 0.01 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000010205>800250000000000000000001252+ 010092520>'
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
        delivery_ids: Delivery.current_year.pluck(:id)[0..1])
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Petit'),
        depot: create(:depot, price: 0),
        basket_price: 21,
        memberships_basket_complements_attributes: {
          '0' => { basket_complement_id: 1 }
        })

      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        object: membership,
        annual_fee: 75,
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
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence('Panier: Petit PUBLIC 4x 21.00', "84.00")
        .and contain_sequence('Oeufs PUBLIC 2x 4.80', "9.60")
        .and contain_sequence('Déjà facturé', '-15.60')
        .and contain_sequence('Montant annuel restant', '78.00')
        .and contain_sequence('Facturation mensuelle #3', "* 7.80")
        .and contain_sequence('* TTC, CHF 7.79 HT, CHF 0.01 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000007809>800250000000000000000001273+ 010092520>'
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end

    it 'generates invoice with support ammount + baskets_annual_price_change reduc + complements', freeze: '2020-04-01' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        started_on: Current.fy_range.min + 2.weeks,
        basket_size: create(:basket_size, name: 'Grand'),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        baskets_annual_price_change: -44,
        memberships_basket_complements_attributes: {
          '1' => { basket_complement_id: 2 }
        })

      invoice = create(:invoice,
        id: 123,
        member: member,
        object: membership,
        annual_fee: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/15.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand PUBLIC 2x 30.50', '61.00')
        .and contain_sequence('Ajustement du prix des paniers', '-44.00')
        .and contain_sequence('Tomme de Lavaux PUBLIC 2x 7.40', '14.80')
        .and contain_sequence('Montant annuel', '31.80', 'Facturation annuelle', '* 31.80')
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Total', "106.80")
        .and contain_sequence('* TTC, CHF 31.77 HT, CHF 0.03 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000106803>800250000000000000000001236+ 010092520>'
      expect(pdf_strings).not_to include 'Montant restant'
    end

    it 'generates invoice with support ammount + basket_complements_annual_price_change reduc + complements', freeze: '2020-04-01' do
      member = create(:member,
        name: 'Alain Reymond',
        address: 'Bd Plumhof 6',
        zip: '1800',
        city: 'Vevey')
      create(:basket_complement,
        id: 2,
        price: 7.4,
        name: 'Tomme de Lavaux',
        delivery_ids: Delivery.current_year.pluck(:id)[2..3])
      membership = create(:membership,
        started_on: Current.fy_range.min + 2.weeks,
        basket_size: create(:basket_size, name: 'Grand'),
        depot: create(:depot, price: 0),
        basket_price: 30.5,
        basket_complements_annual_price_change: -14.15,
        memberships_basket_complements_attributes: {
          '1' => { basket_complement_id: 2 }
        })

      invoice = create(:invoice,
        id: 124,
        member: member,
        object: membership,
        annual_fee: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/15.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand PUBLIC 2x 30.50', '61.00')
        .and contain_sequence('Tomme de Lavaux PUBLIC 2x 7.40', '14.80')
        .and contain_sequence('Ajustement du prix des compléments', '-14.15')
        .and contain_sequence('Montant annuel', '61.65', 'Facturation annuelle', '* 61.65')
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Total', "136.65")
        .and contain_sequence('* TTC, CHF 61.59 HT, CHF 0.06 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and include '0100000136657>800250000000000000000001244+ 010092520>'
      expect(pdf_strings).not_to include 'Montant restant'
    end

    it 'generates an invoice with support and a previous extra payment covering part of its amount' do
      member = create(:member)
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        basket_price: 30.5)
      create(:payment, amount: 42, member: member)

      invoice = create(:invoice,
        id: 242,
        member: member,
        object: membership,
        annual_fee: 75,
        memberships_amount_description: 'Facturation annuelle')

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand PUBLIC 4x 30.50', "122.00")
        .and contain_sequence('Montant annuel', "122.00", 'Facturation annuelle', "* 122.00")
        .and contain_sequence('Cotisation annuelle association', '75.00')
        .and contain_sequence('Balance', "** -42.00")
        .and contain_sequence("À payer", "155.00")
        .and contain_sequence("* TTC, CHF 121.88 HT, CHF 0.12 TVA (0.1%)")
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and contain_sequence("** Différence entre toutes les factures existantes et tous les paiements effectués au moment de l’émission de cette facture.")
        .and contain_sequence("L’historique de votre facturation est disponible à tout moment sur votre page de membre.")
        .and include '0100000155008>800250000000000000000002428+ 010092520>'
        expect(pdf_strings).not_to include 'Montant restant'
    end

    it 'generates an invoice and a previous extra payment covering part of its amount' do
      member = create(:member)
      membership = create(:membership,
        basket_size: create(:basket_size, name: 'Grand'),
        basket_price: 30.5)
      create(:payment, amount: 142, member: member)

      create(:invoice,
        date: Current.fy_range.min,
        member: member,
        object: membership,
        annual_fee: 75,
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
        .to include(/01.04.20\d\d – 31.03.20\d\d/)
        .and contain_sequence('Panier: Grand PUBLIC 4x 30.50', "122.00")
        .and contain_sequence('Déjà facturé', '-10.15')
        .and contain_sequence('Montant annuel restant', "111.85")
        .and contain_sequence('Facturation mensuelle #2', '* 10.15')
        .and contain_sequence('Balance', '** -56.85')
        .and contain_sequence("À payer", '0.00')
        .and contain_sequence('* TTC, CHF 10.14 HT, CHF 0.01 TVA (0.1%)')
        .and contain_sequence('N° TVA CHE-273.220.900')
        .and contain_sequence("** Différence entre toutes les factures existantes et tous les paiements effectués au moment de l’émission de cette facture.")
        .and contain_sequence("L’historique de votre facturation est disponible à tout moment sur votre page de membre.")
        .and contain_sequence('XXXX', 'XX')
        .and include '0100000000005>800250000000000000000002433+ 010092520>'
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end

    it 'generates an invoice for a group buying order' do
      member = create(:member)

      invoice = nil
      travel_to '2019-11-20' do
        delivery = create(:group_buying_delivery,
          orderable_until: '2019-12-02')
        product = create(:group_buying_product,
          name: "Caisse d'orange (1KG)",
          price: 120.45)
        order = create(:group_buying_order,
          delivery: delivery,
          items_attributes: {
            '0' => {
              product_id: product.id,
              quantity: 2
            }
          })
        invoice = order.invoice
      end

      pdf_strings = save_pdf_and_return_strings(invoice)

      expect(pdf_strings)
        .to contain_sequence("Caisse d'orange (1KG) 2x 120.45", '240.90')
        .and contain_sequence("Total", '240.90')
        .and contain_sequence("Payable jusqu'au 2 décembre 2019, avec nos remerciements.")
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end
  end

  context 'TaPatate! settings' do
    before {
      Current.acp.update!(
        name: 'tap',
        logo_url: 'https://d2ibcm5tv7rtdh.cloudfront.net/tapatate/logo.jpg',
        share_price: 250,
        fiscal_year_start_month: 4,
        ccp: '01-9252-0',
        isr_identity: '800350',
        isr_payment_for: "Banque Alternative Suisse SA\n4601 Olten",
        isr_in_favor_of: "TaPatate! c/o Danielle Huser\nDunantstrasse 6\n3006 Bern",
        invoice_info: 'Payable dans les 30 jours, avec nos remerciements.',
        invoice_footer: '<b>TaPatate!<b>, c/o Danielle Huser, Dunantstrasse 6, 3006 Bern /// info@tapatate.ch')
    }

    it 'generates invoice with positive acp_shares_number' do
      member = create(:member,
        name: 'Manuel Rast',
        address: 'Donnerbühlweg 31',
        zip: '3012',
        city: 'Bern',
        acp_shares_info: '345')
      create(:payment, amount: 75, member: member)
      invoice = create(:invoice,
        id: 301,
        member: member,
        acp_shares_number: 2)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence('N° part sociale: 345')
        .and contain_sequence('Acquisition de 2 parts sociales', '500.00')
        .and contain_sequence('Balance', '* -75.00')
        .and contain_sequence('À payer', '425.00')
        .and contain_sequence("* Différence entre toutes les factures existantes et tous les paiements effectués au moment de l’émission de cette facture.")
        .and contain_sequence("L’historique de votre facturation est disponible à tout moment sur votre page de membre.")
    end

    it 'generates invoice with negative acp_shares_number' do
      member = create(:member,
        name: 'Manuel Rast',
        address: 'Donnerbühlweg 31',
        zip: '3012',
        city: 'Bern')
      invoice = create(:invoice,
        id: 302,
        member: member,
        acp_shares_number: -2)
      create(:payment, amount: 75, member: member)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence('Remboursement de 2 parts sociales', "-500.00")
        .and contain_sequence("Total", '-500.00')
      expect(pdf_strings).not_to include 'Avoir'
    end
  end

  context 'QR-Code settings' do
    before {
      Current.acp.update!(
        name: 'qrcode',
        country_code: 'CH',
        ccp: nil,
        isr_identity: nil,
        isr_payment_for: nil,
        isr_in_favor_of: nil,
        qr_iban: 'CH4431999123000889012',
        qr_creditor_name: 'Robert Schneider AG',
        qr_creditor_address: 'Rue du Lac 1268',
        qr_creditor_city: 'Biel',
        qr_creditor_zip: '2501',
        invoice_info: 'Payable dans les 30 jours, avec nos remerciements.',
        invoice_footer: '<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84',
        share_price: 250,
        fiscal_year_start_month: 4)
    }
    let(:member) {
      create(:member,
        name: 'Pia-Maria Rutschmann-Schnyder',
        address: 'Grosse Marktgasse 28',
        zip: '9400',
        city: 'Rorschach',
        country_code: 'CH')
    }

    it 'generates invoice with QR Code' do
      invoice = create(:invoice,
        id: 1001,
        member: member,
        acp_shares_number: 5)

      pdf_strings = save_pdf_and_return_strings(invoice)
      expect(pdf_strings)
        .to contain_sequence('Récépissé')
        .and contain_sequence('Compte / Payable à')
        .and contain_sequence('CH44 3199 9123 0008 8901 2')
        .and contain_sequence('Robert Schneider AG', 'Rue du Lac 1268', '2501 Biel')
        .and contain_sequence('Référence', '00 00000 00000 00000 00000 10014')
        .and contain_sequence('Payable par')
        .and contain_sequence('Pia-Maria Rutschmann-Schnyder', 'Grosse Marktgasse 28', '9400 Rorschach')
        .and contain_sequence('Monnaie', 'CHF')
        .and contain_sequence('Montant', '1 250.00')
        .and contain_sequence('Point de dépôt')
        .and contain_sequence('Section paiement')
        .and contain_sequence('Monnaie', 'CHF')
        .and contain_sequence('Montant', '1 250.00')
        .and contain_sequence('Compte / Payable à')
        .and contain_sequence('CH44 3199 9123 0008 8901 2')
        .and contain_sequence('Robert Schneider AG', 'Rue du Lac 1268', '2501 Biel')
        .and contain_sequence('Référence', '00 00000 00000 00000 00000 10014')
        .and contain_sequence('Informations supplémentaires', 'Facture 1001')
        .and contain_sequence('Payable par')
        .and contain_sequence('Pia-Maria Rutschmann-Schnyder', 'Grosse Marktgasse 28', '9400 Rorschach')
    end
  end

  context 'P2R settings' do
    before {
      Current.acp.update!(
        name: 'p2r',
        logo_url: 'https://d2ibcm5tv7rtdh.cloudfront.net/p2r/logo.jpg',
        fiscal_year_start_month: 1,
        ccp: nil,
        isr_identity: nil,
        isr_payment_for: nil,
        isr_in_favor_of: nil,
        qr_iban: 'CH1830123031135810006',
        qr_creditor_name: 'Le Panier Bio à 2 Roues',
        qr_creditor_address: 'Route de Cery 33',
        qr_creditor_city: 'Prilly',
        qr_creditor_zip: '1008',
        country_code: 'CH',
        currency_code: 'CHF',
        invoice_info: "Payable jusqu'au %{date}, avec nos remerciements.",
        invoice_footer: '<b>Le Panier Bio à 2 Roues</b>, Route de Cery 33, 1008 Prilly /// coordination@p2r.ch, 079 844 43 07',
        shop_invoice_info: "Payable jusqu'au %{date}, avec nos remerciements.")
    }

    it 'generates an invoice for a shop order' do
      member = create(:member)
      product = create(:shop_product,
        name: 'Courge',
        variants_attributes: {
          '0' => {
            name: '5 kg',
            price: 16
          },
          '1' => {
            name: '10 kg',
            price: 30
          }
        })

      invoice = nil
      order = nil
      travel_to '2021-08-21' do
        delivery = create(:delivery, date: '2021-08-26')
        order = create(:shop_order, :pending,
          member: member,
          delivery: delivery,
          items_attributes: {
            '0' => {
              product_id: product.id,
              product_variant_id: product.variants.first.id,
              quantity: 1
            },
            '1' => {
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
        .and contain_sequence("Total", '75.10')
        .and contain_sequence("Payable jusqu'au 26 août 2021, avec nos remerciements.")
      expect(pdf_strings).not_to include 'Cotisation annuelle association'
    end
  end
end

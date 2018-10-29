require 'rails_helper'

describe Email do
  it 'delivers delivery_list template' do
    depot = create(:depot,
      name: 'Jardin de la Main',
      emails: 'john@doe.com, bob@dylan.com')
    delivery = create(:delivery, date: '24.03.2018')

    create(:basket_size, name: 'Eveil')
    create(:member, :active, name: 'Alex Broz')
    create(:member, :active, name: 'Fred Asmo')

    Email.deliver_now(:delivery_list, delivery, depot)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doe.com, bob@dylan.com',
      template: 'delivery-list-fr',
      template_data: {
        delivery_date: '24 mars 2018',
        depot_name: 'Jardin de la Main',
        baskets: [
          { member_name: 'Alex Broz', description: 'Eveil', size_name: 'Eveil' },
          { member_name: 'Fred Asmo', description: 'Eveil', size_name: 'Eveil' }
        ]
      },
      attachments: [
        hash_including(
          name: 'livraison-#1-20180324.xlsx',
          content: String,
          content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml'),
        hash_including(
          name: 'fiches-signature-livraison-#1-20180324.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers halfday_reminder template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    halfday = create(:halfday,
      date: '24.03.2018',
      start_time: Time.zone.parse('8:30'),
      end_time: Time.zone.parse('12:00'),
      place: 'Thielle',
      activity: 'Aide aux champs',
      description: 'Que du bonheur')
    participation = create(:halfday_participation,
      member: member,
      halfday: halfday,
      participants_count: 2)
    create(:halfday_participation, :carpooling,
      halfday: halfday,
      member: create(:member, name: 'Elea Asah'),
      carpooling_phone: '+41765431243',
      carpooling_city: 'La Chaux-de-Fonds')

    Email.deliver_later(:halfday_reminder, participation)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'halfday-reminder-fr',
      template_data: {
        halfday_date: '24 mars 2018',
        halfday_date_long: 'samedi 24 mars 2018',
        halfday_period: '8:30-12:00',
        halfday_activity: 'Aide aux champs',
        halfday_description: 'Que du bonheur',
        halfday_place_name: 'Thielle',
        halfday_participants_count: 2,
        halfday_participations_with_carpooling: [
          member_name: 'Elea Asah',
          carpooling_phone: '076 543 12 43',
          carpooling_city: 'La Chaux-de-Fonds'
        ],
        action_url: 'https://membres.ragedevert.ch'
      },
      attachments: [])
  end

  it 'delivers halfday_validated template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    halfday = create(:halfday,
      date: '24.03.2018',
      start_time: Time.zone.parse('8:30'),
      end_time: Time.zone.parse('12:00'),
      place: 'Thielle',
      place_url: 'https://google.map/thielle',
      activity: 'Aide aux champs',
      description: 'Que du bonheur')
    participation = create(:halfday_participation, :validated,
      member: member,
      halfday: halfday,
      participants_count: 1)

    Email.deliver_later(:halfday_validated, participation)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'halfday-validated-fr',
      template_data: {
        halfday_date: '24 mars 2018',
        halfday_date_long: 'samedi 24 mars 2018',
        halfday_period: '8:30-12:00',
        halfday_activity: 'Aide aux champs',
        halfday_description: 'Que du bonheur',
        halfday_place: {
          name: 'Thielle',
          url: 'https://google.map/thielle'
        },
        halfday_participants_count: 1,
        action_url: 'https://membres.ragedevert.ch'
      },
      attachments: [])
  end

  it 'delivers halfday_rejected template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    halfday = create(:halfday,
      date: '24.03.2018',
      start_time: Time.zone.parse('8:30'),
      end_time: Time.zone.parse('12:00'),
      place: 'Thielle',
      place_url: 'https://google.map/thielle',
      activity: 'Aide aux champs',
      description: 'Que du bonheur')
    participation = create(:halfday_participation, :rejected,
      member: member,
      halfday: halfday,
      participants_count: 3)

    Email.deliver_later(:halfday_rejected, participation)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'halfday-rejected-fr',
      template_data: {
        halfday_date: '24 mars 2018',
        halfday_date_long: 'samedi 24 mars 2018',
        halfday_period: '8:30-12:00',
        halfday_activity: 'Aide aux champs',
        halfday_description: 'Que du bonheur',
        halfday_place: {
          name: 'Thielle',
          url: 'https://google.map/thielle'
        },
        halfday_participants_count: 3,
        action_url: 'https://membres.ragedevert.ch'
      },
      attachments: [])
  end

  it 'delivers invoice_new template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 31,
      date: '24.03.2018',
      annual_fee: 62)

    Email.deliver_later(:invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'invoice-new-fr',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 62.00',
        overdue_notices_count: 0,
        action_url: 'https://membres.ragedevert.ch/billing'
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers invoice_new template (partially paid)' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 31,
      date: '24.03.2018',
      annual_fee: 62)
    create(:payment, member: member, amount: 20)

    Email.deliver_later(:invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'invoice-new-fr',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 62.00',
        invoice_missing_amount: 'CHF 42.00',
        overdue_notices_count: 0,
        action_url: 'https://membres.ragedevert.ch/billing'
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers invoice_new template (paid)' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee,
      member: member,
      id: 31,
      date: '24.03.2018',
      annual_fee: 42)
    create(:payment, member: member, amount: 42)

    Email.deliver_later(:invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'invoice-new-fr',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 42.00',
        invoice_paid: true,
        overdue_notices_count: 0,
        action_url: 'https://membres.ragedevert.ch/billing'
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers invoice_overdue_notice template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee,
      member: member,
      id: 31,
      date: '24.03.2018',
      overdue_notices_count: 2,
      annual_fee: 42)

    Email.deliver_later(:invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'invoice-new-fr',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 42.00',
        invoice_missing_amount: 'CHF 42.00',
        overdue_notices_count: 2,
        action_url: 'https://membres.ragedevert.ch/billing'
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers member_new template' do
    admin = create(:admin, name: 'Thibaud', email: 'thibaud@thibaud.gg')
    member = create(:member, name: 'John Doew')

    Email.deliver_later(:member_new, admin, member)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'thibaud@thibaud.gg',
      template: 'member-new-fr',
      template_data: {
        admin_name: 'Thibaud',
        member_name: 'John Doew',
        action_url: "https://admin.ragedevert.ch/members/#{member.id}"
      },
      attachments: [])
  end
end

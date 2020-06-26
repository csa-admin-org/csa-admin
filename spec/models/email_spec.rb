require 'rails_helper'

describe Email do
  it 'delivers admin-absence-new template' do
    admin = create(:admin,
      name: 'Thibaud',
      email: 'thibaud@thibaud.gg',
      notifications: %w[new_absence])

    member = create(:member, name: 'John Doew')

    travel_to '2018-10-01' do
      absence = create(:absence, member: member,
        started_on: '2018-11-12',
        ended_on: '2018-11-19',)

      expect(email_adapter.deliveries.size).to eq 1
      expect(email_adapter.deliveries.first).to eq(
        from: Current.acp.email_default_from,
        to: 'thibaud@thibaud.gg',
        template: 'admin-absence-new',
        template_data: {
          admin_name: 'Thibaud',
          member_name: 'John Doew',
          started_on: '12 novembre 2018',
          ended_on: '19 novembre 2018',
          action_url: "https://admin.ragedevert.ch/absences/#{absence.id}",
          edit_admin_url: "https://admin.ragedevert.ch/admins/#{admin.id}/edit#admin_notifications_input",
          fr: true
        },
        attachments: [])
    end
  end

  it 'delivers admin-delivery-list template' do
    travel_to '2018-03-01' do
      delivery = create(:delivery, date: '24.03.2018')
      depot = create(:depot,
        name: 'Jardin de la Main',
        emails: 'john@doe.com, bob@dylan.com',
        delivery_ids: [delivery.id])
      basket_size = create(:basket_size, name: 'Eveil')
      create(:membership,
        basket_size: basket_size,
        depot: depot,
        member: create(:member, name: 'Alex Broz'))
      create(:membership,
        basket_size: basket_size,
        depot: depot,
        member: create(:member, name: 'Fred Asmo'))

      Email.deliver_now(:admin_delivery_list, delivery, depot)

      expect(email_adapter.deliveries.size).to eq 1
      expect(email_adapter.deliveries.first).to match(hash_including(
        from: Current.acp.email_default_from,
        to: 'john@doe.com, bob@dylan.com',
        template: 'admin-delivery-list',
        template_data: {
          delivery_date: '24 mars 2018',
          depot_name: 'Jardin de la Main',
          baskets: [
            { member_name: 'Alex Broz', description: 'Eveil', size_name: 'Eveil' },
            { member_name: 'Fred Asmo', description: 'Eveil', size_name: 'Eveil' }
          ],
          fr: true
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
  end

  it 'delivers admin-invitation template' do
    admin = create(:admin,
      name: 'John Doe',
      email: 'john@doe.com',
      language: 'fr')

    Email.deliver_later(:admin_invitation, admin)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      to: 'john@doe.com',
      template: 'admin-invitation',
      template_data: {
        admin_name: 'John Doe',
        admin_email: 'john@doe.com',
        action_url: 'https://admin.ragedevert.ch',
        edit_admin_url: "https://admin.ragedevert.ch/admins/#{admin.id}/edit#admin_notifications_input",
        fr: true
      }))
  end

  it 'delivers admin-invoice-overpaid template' do
    admin = create(:admin,
      name: 'Thibaud',
      email: 'thibaud@thibaud.gg',
      notifications: %w[invoice_overpaid])
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee, member: member)

    Email.deliver_later(:admin_invoice_overpaid, admin, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'thibaud@thibaud.gg',
      template: 'admin-invoice-overpaid',
      template_data: {
        admin_name: 'Thibaud',
        invoice_number: invoice.id,
        member_name: 'John Doew',
        action_url: "https://admin.ragedevert.ch/members/#{member.id}",
        edit_admin_url: "https://admin.ragedevert.ch/admins/#{admin.id}/edit#admin_notifications_input",
        fr: true
      }))
  end

  it 'delivers admin-member-new template' do
    admin = create(:admin,
      name: 'Thibaud',
      email: 'thibaud@thibaud.gg',
      notifications: %w[new_inscription])
    member = create(:member, name: 'John Doew', public_create: true)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'thibaud@thibaud.gg',
      template: 'admin-member-new',
      template_data: {
        admin_name: 'Thibaud',
        member_name: 'John Doew',
        action_url: "https://admin.ragedevert.ch/members/#{member.id}",
        edit_admin_url: "https://admin.ragedevert.ch/admins/#{admin.id}/edit#admin_notifications_input",
        fr: true
      },
      attachments: [])
  end

  it 'delivers member-activated template', freeze: '2020-01-01' do
    member = create(:member, :inactive, emails: 'john@doe.com')
    basket_size = create(:basket_size,
      activity_participations_demanded_annualy: 3)
    Current.acp.update!(
      notification_member_activated: '1',
      trial_basket_count: 4)

    # activate the member
    create(:membership,
      member: member,
      basket_size: basket_size,
      started_on: '2020-02-01',
      ended_on: '2020-12-31')

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'john@doe.com',
      template: 'member-activated',
      template_data: {
        action_url: 'https://membres.ragedevert.ch',
        fr: true,
        membership_start_date: '1 février 2020',
        membership_end_date: '31 décembre 2020',
        "basket_size_id_#{basket_size.id}": true,
        "depot_id_#{Depot.first.id}": true,
        trial_baskets: 4,
        activity_participations_demanded: 3
      },
      attachments: [])
  end

  it 'delivers member-activity-reminder template' do
    member = create(:member, emails: 'john@doew.com')
    activity = create(:activity,
      date: '24.03.2018',
      start_time: Time.zone.parse('8:30'),
      end_time: Time.zone.parse('12:00'),
      place: 'Thielle',
      title: 'Aide aux champs',
      description: 'Que du bonheur')
    participation = create(:activity_participation,
      member: member,
      activity: activity,
      participants_count: 2)
    create(:activity_participation, :carpooling,
      activity: activity,
      member: create(:member, name: 'Elea Asah'),
      carpooling_phone: '+41765431243',
      carpooling_city: 'La Chaux-de-Fonds')

    Email.deliver_later(:member_activity_reminder, participation)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-activity-reminder',
      template_data: {
        activity_date: '24 mars 2018',
        activity_date_long: 'samedi 24 mars 2018',
        activity_period: '8:30-12:00',
        activity_title: 'Aide aux champs',
        activity_description: 'Que du bonheur',
        activity_place_name: 'Thielle',
        activity_participants_count: 2,
        activity_participations_with_carpooling: [
          member_name: 'Elea Asah',
          carpooling_phone: '076 543 12 43',
          carpooling_city: 'La Chaux-de-Fonds'
        ],
        action_url: 'https://membres.ragedevert.ch',
        fr: true
      },
      attachments: [])
  end

  it 'delivers member-activity-validated template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    activity = create(:activity,
      date: '24.03.2018',
      start_time: Time.zone.parse('8:30'),
      end_time: Time.zone.parse('12:00'),
      place: 'Thielle',
      place_url: 'https://google.map/thielle',
      title: 'Aide aux champs',
      description: 'Que du bonheur')
    participation = create(:activity_participation, :validated,
      member: member,
      activity: activity,
      participants_count: 1)

    Email.deliver_later(:member_activity_validated, participation)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-activity-validated',
      template_data: {
        activity_date: '24 mars 2018',
        activity_date_long: 'samedi 24 mars 2018',
        activity_period: '8:30-12:00',
        activity_title: 'Aide aux champs',
        activity_description: 'Que du bonheur',
        activity_place: {
          name: 'Thielle',
          url: 'https://google.map/thielle'
        },
        activity_participants_count: 1,
        action_url: 'https://membres.ragedevert.ch',
        fr: true
      },
      attachments: [])
  end

  it 'delivers member-activity-rejected template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    activity = create(:activity,
      date: '24.03.2018',
      start_time: Time.zone.parse('8:30'),
      end_time: Time.zone.parse('12:00'),
      place: 'Thielle',
      place_url: 'https://google.map/thielle',
      title: 'Aide aux champs',
      description: 'Que du bonheur')
    participation = create(:activity_participation, :rejected,
      member: member,
      activity: activity,
      participants_count: 3)

    Email.deliver_later(:member_activity_rejected, participation)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to eq(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-activity-rejected',
      template_data: {
        activity_date: '24 mars 2018',
        activity_date_long: 'samedi 24 mars 2018',
        activity_period: '8:30-12:00',
        activity_title: 'Aide aux champs',
        activity_description: 'Que du bonheur',
        activity_place: {
          name: 'Thielle',
          url: 'https://google.map/thielle'
        },
        activity_participants_count: 3,
        action_url: 'https://membres.ragedevert.ch',
        fr: true
      },
      attachments: [])
  end

  it 'delivers member-invoice-new template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 31,
      date: '24.03.2018',
      annual_fee: 62)

    Email.deliver_later(:member_invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-invoice-new',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 62.00',
        overdue_notices_count: 0,
        action_url: 'https://membres.ragedevert.ch/billing',
        annual_fee: true,
        fr: true
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers member-invoice-new template (partially paid)' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee, :open,
      member: member,
      id: 31,
      date: '24.03.2018',
      annual_fee: 62)
    create(:payment, member: member, amount: 20)

    Email.deliver_later(:member_invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-invoice-new',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 62.00',
        invoice_missing_amount: 'CHF 42.00',
        overdue_notices_count: 0,
        action_url: 'https://membres.ragedevert.ch/billing',
        annual_fee: true,
        fr: true
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers member-invoice-new template (paid)' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee,
      member: member,
      id: 31,
      date: '24.03.2018',
      annual_fee: 42)
    create(:payment, member: member, amount: 42)

    Email.deliver_later(:member_invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-invoice-new',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 42.00',
        invoice_paid: true,
        overdue_notices_count: 0,
        action_url: 'https://membres.ragedevert.ch/billing',
        annual_fee: true,
        fr: true
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers member-invoice-new template' do
    member = create(:member,
      name: 'John Doew',
      emails: 'john@doew.com')
    invoice = create(:invoice, :annual_fee,
      member: member,
      id: 31,
      date: '24.03.2018',
      overdue_notices_count: 2,
      annual_fee: 42)

    Email.deliver_later(:member_invoice_new, invoice)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-invoice-new',
      template_data: {
        invoice_number: invoice.id,
        invoice_date: '24 mars 2018',
        invoice_amount: 'CHF 42.00',
        invoice_missing_amount: 'CHF 42.00',
        overdue_notices_count: 2,
        action_url: 'https://membres.ragedevert.ch/billing',
        annual_fee: true,
        fr: true
      },
      attachments: [
        hash_including(
          name: 'facture-ragedevert-31.pdf',
          content: String,
          content_type: 'application/pdf'),
      ]))
  end

  it 'delivers member-validated template' do
    member = create(:member, :pending, emails: 'john@doew.com')
    admin = create(:admin)
    Current.acp.update!(notification_member_validated: '1')

    member.validate!(admin)

    expect(email_adapter.deliveries.size).to eq 1
    expect(email_adapter.deliveries.first).to match(hash_including(
      from: Current.acp.email_default_from,
      to: 'john@doew.com',
      template: 'member-validated',
      template_data: {
        action_url: 'https://membres.ragedevert.ch',
        members_waiting_count: 1,
        fr: true
      }))
  end
end

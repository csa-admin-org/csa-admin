class AdminMailerPreview < ActionMailer::Preview
  def depot_delivery_list_email
    depot = Depot.new(
      name: 'Jardin de la Main',
      language: I18n.locale,
      emails: 'respondent1@acp-admin.ch, respondent2@acp-admin.ch')
    delivery = Delivery.new(date: Date.new(2020, 11, 10))
    baskets = [
      OpenStruct.new(
        member: Member.new(name: 'Martha'),
        description: 'Petit Panier'),
      OpenStruct.new(
        member: Member.new(name: 'Bob'),
        description: 'Grand Panier'),
      OpenStruct.new(
        member: Member.new(name: 'Josh'),
        description: 'Petit Panier')
    ]
    AdminMailer.with(
      depot: depot,
      baskets: baskets,
      delivery: delivery
    ).depot_delivery_list_email
  end

  def invitation_email
    admin = Admin.new(
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    AdminMailer.with(
      admin: admin,
      action_url: 'https://admin.example.com',
    ).invitation_email
  end

  def invoice_overpaid_email
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(
      id: 2,
      name: 'Martha')
    invoice = Invoice.new(id: 42)
    AdminMailer.with(
      admin: admin,
      member: member,
      invoice: invoice
    ).invoice_overpaid_email
  end

  def new_absence_email
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member = Member.new(name: 'Martha')
    absence = Absence.new(
      id: 1,
      started_on: Date.new(2020, 11, 10),
      ended_on: Date.new(2020, 11, 20))
    AdminMailer.with(
      admin: admin,
      member: member,
      absence: absence
    ).new_absence_email
  end

  def new_inscription_email
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(
      id: 2,
      name: 'Martha')
    AdminMailer.with(
      admin: admin,
      member: member
    ).new_inscription_email
  end
end

class AdminMailerPreview < ActionMailer::Preview
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

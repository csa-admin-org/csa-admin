class AdminMailer < ApplicationMailer
  layout false

  def new_inscription(member)
    @member = member
    admin_emails = Admin.pluck(:email) - %w[tguignard@gmail.com]
    mail(
      to: admin_emails.delete('chantalgraef@gmail.com'),
      cc: admin_emails,
      subject: 'Rage de Vert: nouvelle inscription à valider'
    )
  end
end

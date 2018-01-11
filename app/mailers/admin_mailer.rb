class AdminMailer < ApplicationMailer
  layout false

  def new_inscription(member)
    @member = member
    mail(
      to: Admin.notification('new_inscription').pluck(:email),
      subject: "#{Current.acp.name}: nouvelle inscription à valider")
  end
end

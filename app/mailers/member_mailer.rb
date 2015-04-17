class MemberMailer < ActionMailer::Base
  default(
    from: 'info@ragedevert.ch',
    subject: 'Rage de Vert: votre page de membre'
  )
  layout 'member_mailer'

  def welcome(member)
    @member = member
    mail(to: member.emails)
  end

  def recover_token(email, member)
    @member = member
    mail(to: email)
  end
end

class MemberMailer < ActionMailer::Base
  default from: 'info@ragedevert.ch'
  layout 'member_mailer'

  def welcome(member)
    @member = member
    mail(to: member.emails, subject: 'Rage de Vert: votre page de membre')
  end

  def recover_token(email, member)
    @member = member
    mail(to: email, subject: 'Rage de Vert: votre page de membre')
  end
end

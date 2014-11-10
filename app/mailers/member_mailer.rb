class MemberMailer < ActionMailer::Base
  default from: 'info@ragedevert.ch'

  def recover_token_email(email, member)
    @member = member
    mail(to: email, subject: 'Rage de Vert: votre page de membre')
  end
end

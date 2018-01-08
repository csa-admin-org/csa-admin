class MemberMailer < ApplicationMailer
  default subject: -> { "#{Current.acp.name}: votre page de membre" }

  def welcome(member)
    @member = member
    mail to: member.emails
  end

  def recover_token(email, member)
    @member = member
    mail to: email
  end
end

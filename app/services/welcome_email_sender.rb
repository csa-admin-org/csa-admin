class WelcomeEmailSender
  attr_reader :members

  def self.send(*args)
    new(*args).send
  end

  def initialize
    @members = Member.active.where(welcome_email_sent_at: nil).select { |member|
      !member.salary_basket? && member.emails?
    }
  end

  def send
    members.each do |member|
      member.transaction do
        MemberMailer.welcome(member).deliver_now
        member.touch(:welcome_email_sent_at)
      end
    end
  end
end

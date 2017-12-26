class WelcomeEmailSender
  attr_reader :members

  def self.send(*args)
    new(*args).send
  end

  def initialize
    @members =
      Member
        .active
        .where(welcome_email_sent_at: nil, salary_basket: false)
        .select { |member| member.emails? }
  end

  def send
    members.each do |member|
      MemberMailer.welcome(member).deliver_now
      member.touch(:welcome_email_sent_at)
    end
  end
end

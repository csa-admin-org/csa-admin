class ComingHalfdayWorkEmailSender
  attr_reader :halfday_works

  def self.send(*args)
    new(*args).send
  end

  def initialize
    @halfday_works = HalfdayWork.where(date: 3.days.from_now)
  end

  def send
    halfday_works.each do |halfday_work|
      HalfdayWorkMailer.coming(halfday_work).deliver_now
    end
  end
end

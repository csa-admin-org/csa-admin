class HalfdayMailer < ApplicationMailer
  helper :halfdays

  def coming(halfday_participation)
    @halfday_participation = halfday_participation
    @halfday_participations_with_carpooling =
      HalfdayParticipation.carpooling(halfday_participation.halfday.date)
    @member = halfday_participation.member
    mail(to: @member.emails, subject: subject('à venir'))
  end

  def validated(halfday_participation)
    @halfday_participation = halfday_participation
    @member = halfday_participation.member
    mail(to: @member.emails, subject: subject('validée'))
  end

  def rejected(halfday_participation)
    @halfday_participation = halfday_participation
    @member = halfday_participation.member
    mail(to: @member.emails, subject: subject('refusée'))
  end

  def recall(member)
    @member = member
    mail(to: @member.emails, subject: "#{Current.acp.name}: ½ journées de travail")
  end

  private

  def subject(type)
    date = l(@halfday_participation.halfday.date, format: :long).sub(/^\s/, '')
    "#{Current.acp.name}: ½ journée de travail #{type} (#{date})"
  end
end

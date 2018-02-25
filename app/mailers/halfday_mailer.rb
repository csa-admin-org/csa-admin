class HalfdayMailer < ApplicationMailer
  include HalfdaysHelper

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

  private

  def subject(type)
    date = l(@halfday_participation.halfday.date, format: :long).sub(/^\s/, '')
    "#{Current.acp.name}: #{halfday_human_name} #{type} (#{date})"
  end
end

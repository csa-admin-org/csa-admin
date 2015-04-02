class HalfdayWorkMailer < ActionMailer::Base
  default from: 'info@ragedevert.ch'
  layout 'member_mailer'
  helper :halfday_works

  def coming(halfday_work)
    @halfday_work = halfday_work
    @member = halfday_work.member
    # TODO Ajouter date @halfday_work.date, format: :long
    mail(to: @member.emails, subject: subject('à venir'))
  end

  def validated(halfday_work)
    @halfday_work = halfday_work
    @member = halfday_work.member
    mail(to: @member.emails, subject: subject('validée'))
  end

  def rejected(halfday_work)
    @halfday_work = halfday_work
    @member = halfday_work.member
    mail(to: @member.emails, subject: subject('refusée'))
  end

  private

  def subject(type)
    date = l(@halfday_work.date, format: :long).sub(/^\s/, '')
    "Rage de Vert: ½ journée de travail #{type} (#{date})"
  end
end

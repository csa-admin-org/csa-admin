class HalfdayWorkMailer < ApplicationMailer
  helper :halfday_works

  def coming(halfday_work)
    @halfday_work = halfday_work
    @member = halfday_work.member
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

  def recall(member)
    @member = member
    mail(to: @member.emails, subject: 'Rage de Vert: ½ journées de travail')
  end

  private

  def subject(type)
    date = l(@halfday_work.date, format: :long).sub(/^\s/, '')
    "Rage de Vert: ½ journée de travail #{type} (#{date})"
  end
end

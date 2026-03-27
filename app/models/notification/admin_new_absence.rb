# frozen_string_literal: true

class Notification::AdminNewAbsence < Notification::Base
  def notify
    eligible_absences.find_each do |absence|
      notify_admins(absence)
      absence.touch(:admins_notified_at)
    end
  end

  private

  def eligible_absences
    Absence
      .where(created_at: 1.day.ago..5.minutes.ago, admins_notified_at: nil)
      .includes(:member, :session)
  end

  def notify_admins(absence)
    attrs = {
      absence: absence,
      member: absence.member,
      skip: absence.session&.admin
    }
    if absence.note?
      attrs[:reply_to] = [ absence.session&.email, *absence.member.emails_array ].compact.uniq
    end
    Admin.notify!(:new_absence, **attrs)
    Admin.notify!(:new_absence_with_note, **attrs) if absence.note?
  end
end

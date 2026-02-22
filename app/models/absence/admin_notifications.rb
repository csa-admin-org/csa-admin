# frozen_string_literal: true

module Absence::AdminNotifications
  extend ActiveSupport::Concern

  included do
    attr_accessor :admin

    after_create_commit :notify_admins!
  end

  private

  def notify_admins!
    attrs = {
      absence: self,
      member: member,
      skip: admin
    }
    if note?
      attrs[:reply_to] = [ session&.email, *member.emails_array ].compact.uniq
    end
    Admin.notify!(:new_absence, **attrs)
    Admin.notify!(:new_absence_with_note, **attrs) if note?
  end
end

# frozen_string_literal: true

class Absence < ApplicationRecord
  include Period, AdminNotifications
  include HasNote, HasComment

  belongs_to :member
  belongs_to :session, optional: true
  has_many :baskets, dependent: :nullify
  has_many :basket_shifts, dependent: :destroy

  after_commit :update_memberships!
  after_commit -> { MailTemplate.deliver_later(:absence_created, absence: self) }

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[including_date during_year]
  end

  private

  def update_memberships!
    min = [ started_on_previously_was, started_on ].compact.min
    max = [ ended_on_previously_was, ended_on ].compact.max
    member.memberships.overlaps(min..max).find_each(&:save!)
  end
end

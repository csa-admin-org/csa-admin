# frozen_string_literal: true

class Admin < ApplicationRecord
  include HasSessions

  attribute :language, :string, default: -> { Current.org.languages.first }

  belongs_to :permission
  has_many :validated_member,
    class_name: "ActivityParticipation",
    foreign_key: :validator_id,
    dependent: :nullify
  has_many :validated_activity_participations,
    class_name: "ActivityParticipation",
    foreign_key: :validator_id,
    dependent: :nullify

  scope :notification, ->(notification) {
    where("EXISTS (SELECT 1 FROM json_each(notifications) WHERE json_each.value = ?)", notification)
  }
  scope :with_email, ->(email) { where("lower(email) = ?", email.downcase) }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :language, presence: true, inclusion: { in: proc { Organization.languages } }
  validate :truemail

  after_create -> { Update.mark_as_read!(self) }

  def self.master
    find_by(email: ENV["MASTER_ADMIN_EMAIL"])
  end

  def self.notify!(notification, skip: [], **attrs)
    Admin.notification(notification).where.not(id: skip).find_each do |admin|
      next if EmailSuppression.outbound.active.exists?(email: admin.email)

      email = notification.to_s.delete_suffix("_with_note") + "_email"
      attrs[:admin] = admin
      AdminMailer
        .with(**attrs)
        .send(email)
        .deliver_later
    end
  end

  def self.notifications
    all = %w[
      delivery_list
      new_email_suppression
      new_inscription
      invoice_overpaid
      invoice_third_overdue_notice
      memberships_renewal_pending
    ]
    if Current.org.feature?("absence")
      all << "new_absence"
      all << "new_absence_with_note" # only with note
    end
    if Current.org.feature?("activity")
      all << "new_activity_participation"
      all << "new_activity_participation_with_note" # only with note
    end
    all
  end

  def notifications=(notifications)
    super(notifications.map(&:presence).compact)
  end

  def master?
    email == ENV["MASTER_ADMIN_EMAIL"]
  end

  def email=(email)
    super(email.downcase.strip)
  end

  private

  def truemail
    if email.present? && email_changed? && !Truemail.valid?(email)
      errors.add(:email, :invalid)
    end
  end
end

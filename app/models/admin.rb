# frozen_string_literal: true

class Admin < ApplicationRecord
  include HasName
  include HasSessions

  attribute :language, :string, default: -> { Current.org.languages.first }
  normalizes :email, with: ->(email) { email.downcase.strip }

  belongs_to :permission
  has_many :validated_member,
    class_name: "ActivityParticipation",
    foreign_key: :validator_id,
    dependent: :nullify
  has_many :validated_activity_participations,
    class_name: "ActivityParticipation",
    foreign_key: :validator_id,
    dependent: :nullify
  has_many :tickets,
    class_name: "Support::Ticket",
    foreign_key: :admin_id,
    dependent: :nullify

  scope :notification, ->(notification) {
    where("EXISTS (SELECT 1 FROM json_each(notifications) WHERE json_each.value = ?)", notification)
  }
  scope :with_email, ->(email) { where("lower(email) = ?", email.downcase) }

  validates :email, presence: true, uniqueness: true
  validates :language, presence: true, inclusion: { in: proc { Organization.languages } }
  validate :truemail

  after_create -> { Update.mark_as_read!(self) }

  def self.ultra
    find_by(email: ENV["ULTRA_ADMIN_EMAIL"])
  end

  def self.create_ultra!
    return unless ENV["ULTRA_ADMIN_EMAIL"]

    create!(
      email: ENV["ULTRA_ADMIN_EMAIL"],
      name: ENV["ULTRA_ADMIN_NAME"],
      language: ENV["ULTRA_ADMIN_LANGUAGE"],
      permission: Permission.superadmin)
  end

  def self.notify!(notification, skip: [], **attrs)
    Admin.notification(notification).where.not(id: skip).find_each do |admin|
      next if EmailSuppression.outbound.active.exists?(email: admin.email)
      next if admin.skip_with_note?(notification)

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
      new_registration
      invoice_overpaid
      invoice_third_overdue_notice
      payment_reversal
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

  def skip_with_note?(notification)
    notification.ends_with?("_with_note") && notifications.include?(notification.to_s.delete_suffix("_with_note"))
  end

  def notifications=(notifications)
    super(notifications.map(&:presence).compact)
  end

  def ultra?
    email == ENV["ULTRA_ADMIN_EMAIL"]
  end

  private

  def truemail
    if email.present? && email_changed? && !Truemail.valid?(email)
      errors.add(:email, :invalid)
    end
  end
end

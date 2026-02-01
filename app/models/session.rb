# frozen_string_literal: true

require "user_agent_parser"

class Session < ApplicationRecord
  EXPIRATION = 1.year

  generates_token_for :redeem, expires_in: 15.minutes do
    last_used_at # Invalidate token once used
  end

  belongs_to :member, optional: true
  belongs_to :admin, optional: true

  validates :remote_addr, :user_agent, presence: true
  validates :email, presence: true, allow_nil: true
  validate :truemail
  validate :owner_must_be_present
  validate :email_must_not_be_suppressed

  scope :used, -> { where.not(last_used_at: nil) }
  scope :recent, -> { where(last_used_at: 1.month.ago..) }
  scope :active, -> { where(created_at: EXPIRATION.ago..) }
  scope :expired, -> { where(created_at: ...EXPIRATION.ago) }
  scope :usable, -> { where(revoked_at: nil).where.not(email: nil) }
  scope :admin, -> { where.not(admin_id: nil) }
  scope :member, -> { where.not(member_id: nil) }
  scope :owner_type_eq, ->(type) {
    case type
    when "Admin" then admin.where(member_id: nil)
    when "Member" then member
    end
   }

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[owner_type_eq]
  end

  def owner_type
    member_id ? "Member" : "Admin"
  end

  def owner
    member || admin
  end

  def member_email=(email)
    email = email.downcase.strip
    self[:email] = email
    # Only allow login for kept (non-discarded) members
    self.member = Member.kept.find_by_email(email)
  end

  def admin_email=(email)
    email = email.downcase.strip
    self[:email] = email
    self.admin = Admin.find_by(email: email)
  end

  def request=(request)
    self[:remote_addr] = request.remote_addr
    self[:user_agent] = request.env.fetch("HTTP_USER_AGENT", "-")
  end

  def expires_at
    created_at + (admin_originated? ? 6.hours : EXPIRATION)
  end

  def expired?
    expires_at.past?
  end

  def revoke!
    touch(:revoked_at)
  end

  def revoked?
    revoked_at?
  end

  def admin_originated?
    member && admin
  end

  def last_user_agent
    user_agent = self[:last_user_agent]
    return unless user_agent.present?

    UserAgentParser.parse(user_agent)
  end

  private

  def truemail
    if email.present? && !Truemail.valid?(email)
      errors.add(:email, :invalid)
    end
  end

  def owner_must_be_present
    return unless email.present?

    unless member_id || admin_id
      errors.add(:email, :unknown)
    end
  end

  def email_must_not_be_suppressed
    if owner && EmailSuppression.outbound.active.exists?(email: email)
      errors.add(:email, :suppressed)
    end
  end
end

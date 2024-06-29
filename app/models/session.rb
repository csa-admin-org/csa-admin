# frozen_string_literal: true

class Session < ApplicationRecord
  TIMEOUT = 1.hour
  EXPIRATION = 1.year

  belongs_to :member, optional: true
  belongs_to :admin, optional: true

  validates :remote_addr, :token, :user_agent, presence: true
  validates :email, presence: true, allow_nil: true
  validate :truemail
  validate :owner_must_be_present
  validate :email_must_not_be_suppressed

  before_validation :set_unique_token

  scope :used, -> { where.not(last_used_at: nil) }
  scope :recent, -> { where(last_used_at: 1.month.ago..) }
  scope :active, -> { where(created_at: EXPIRATION.ago..) }
  scope :expired, -> { where(created_at: ...EXPIRATION.ago) }
  scope :admin, -> { where.not(admin_id: nil) }
  scope :member, -> { where.not(member_id: nil) }
  scope :owner_type_eq, ->(type) {
    case type
    when "Admin" then admin
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
    self.member = Member.find_by_email(email)
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

  def timeout?
    timeout_at < Time.current
  end

  def timeout_at
    created_at + TIMEOUT
  end

  def expires_at
    created_at + (admin_originated? ? 6.hours : EXPIRATION)
  end

  def expired?
    !email || expires_at < Time.current
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

  def set_unique_token
    self.token ||= loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless Session.find_by(token: token)
    end
  end

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

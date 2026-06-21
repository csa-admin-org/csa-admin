# frozen_string_literal: true

require "user_agent_parser"

class Session < ApplicationRecord
  include Session::DeletionCode
  EXPIRATION = 1.year
  RETENTION = 15.months

  generates_token_for :redeem, expires_in: 15.minutes do
    Tenant.current
  end

  belongs_to :member, optional: true
  belongs_to :admin, optional: true
  has_many :absences, dependent: :nullify
  has_many :activity_participations, dependent: :nullify
  has_many :audits, dependent: :nullify
  has_many :basket_overrides, dependent: :nullify
  has_many :demo_page_visits, class_name: "Demo::PageVisit", dependent: :delete_all
  has_many :sepa_mandates, class_name: "SEPAMandate", dependent: :nullify

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

  def self.redeem_token(token, owner_type:)
    find_by_token_for(:redeem, token)&.redeem_as(owner_type)
  end

  def self.clear_stale!
    where(created_at: ...RETENTION.ago).find_each(&:destroy!)
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
    self[:remote_addr] = request&.remote_addr || "127.0.0.1"
    self[:user_agent] = request&.env&.dig("HTTP_USER_AGENT") || "-"
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

  def redeem_as(owner_type)
    with_lock do
      tap(&:redeem!) if redeemable_as?(owner_type)
    end
  end

  def redeem!
    touch(:redeemed_at)
  end

  def masked_login_error?
    email_errors = errors.details[:email]
    email_errors.present?
      && errors.details.except(:email).empty?
      && email_errors.all? { |error| error[:error].in?(%i[unknown suppressed]) }
  end

  def revoked?
    revoked_at?
  end

  def admin_originated?
    member && admin
  end

  def redeemable_as?(owner_type)
    return false unless redeemable?

    case owner_type
    when :admin then admin_session?
    when :member then member_session?
    end
  end

  def last_user_agent
    user_agent = self[:last_user_agent]
    return unless user_agent.present?

    UserAgentParser.parse(user_agent)
  end

  private

  def redeemable?
    email? && !revoked? && !redeemed_at? && !expired?
  end

  def admin_session?
    admin_id? && !member_id?
  end

  def member_session?
    member_id?
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

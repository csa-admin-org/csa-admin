class Session < ApplicationRecord
  TIMEOUT = 1.hour
  EXPIRATION = 1.year

  belongs_to :member, optional: true
  belongs_to :admin, optional: true

  validates :email, format: /.+\@.+\..+/, allow_nil: true
  validates :remote_addr, :token, :user_agent, presence: true
  validate :owner_must_be_present

  before_validation :set_unique_token

  scope :expired, -> { where('created_at > ?', EXPIRATION.ago) }
  scope :admin, -> { where.not(admin_id: nil) }
  scope :member, -> { where.not(member_id: nil) }

  def member_email=(email)
    self[:email] = email
    self.member = Member.find_by_email(email)
  end

  def admin_email=(email)
    self[:email] = email
    self.admin = Admin.find_by(email: email)
  end

  def timeout?
    timeout_at < Time.current
  end

  def timeout_at
    created_at + TIMEOUT
  end

  def expires_at
    created_at + EXPIRATION
  end

  def expired?
    !email || expires_at < Time.current
  end

  private

  def set_unique_token
    self.token ||= loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless Session.find_by(token: token)
    end
  end

  def owner_must_be_present
    errors.add(:base, :invalid) unless [member_id, admin_id].one?(&:present?)
  end
end

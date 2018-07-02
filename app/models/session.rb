class Session < ApplicationRecord
  TIMEOUT = 1.hour
  EXPIRATION = 1.year

  attr_reader :email

  belongs_to :member

  validates :remote_addr, :token, :user_agent, presence: true

  before_validation :set_unique_token

  scope :expired, -> { where('created_at > ?', EXPIRATION.ago) }

  def email=(email)
    @email = email
    self.member = Member.with_email(email).first
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
    expires_at < Time.current
  end

  private

  def set_unique_token
    self.token ||= loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless Session.find_by(token: token)
    end
  end
end

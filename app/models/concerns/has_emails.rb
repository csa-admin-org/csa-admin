module HasEmails
  extend ActiveSupport::Concern

  included do
    attr_accessor :email

    validate :emails_must_be_valid

    scope :with_email, ->(email) { where('emails ILIKE ?', "%#{email}%") }
    scope :including_email, ->(email) {
      where("lower(emails) ~ ('(^|,\s)' || lower(?) || '(,\s|$)')", Regexp.escape(email))
    }
  end

  class_methods do
    def find_by_email(email)
      including_email(email).first
    end
  end

  def emails=(emails)
    super string_to_a(emails.downcase).join(', ')
  end

  def emails_array
    string_to_a(emails).sort
  end

  def active_emails
    emails_array.reject { |email| EmailSuppression.active.exists?(email: email) }
  end

  def emails?
    active_emails.any?
  end

  private

  def emails_must_be_valid
    emails_array.each do |email|
      unless email.match?(ACP::EMAIL_REGEXP)
        errors.add(:emails, :invalid)
        break
      end
    end
  end

  def string_to_a(str)
    str.to_s.split(',').map { |s| s.gsub(/[[:space:]]/, '') }
  end
end

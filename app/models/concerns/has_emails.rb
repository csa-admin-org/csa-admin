module HasEmails
  extend ActiveSupport::Concern

  included do
    attr_accessor :email

    validate :emails_must_be_valid

    scope :with_emails, -> { where.not(emails: ['', nil]) }
    scope :with_email, ->(email) { where('members.emails ILIKE ?', "%#{email}%") }
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
    super string_to_a(emails).join(', ')
  end

  def emails_array
    string_to_a(emails)
  end

  def emails?
    emails_array.present?
  end

  private

  def emails_must_be_valid
    emails_array.each do |email|
      unless email.match?(/^[^@\s]+@[^@\s]+\.[^@\s]+$/)
        errors.add(:emails, :invalid)
        break
      end
    end
  end

  def string_to_a(str)
    str.to_s.split(',').map { |s| s.gsub(/[[:space:]]/, '') }
  end
end

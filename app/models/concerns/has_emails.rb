module HasEmails
  extend ActiveSupport::Concern

  included do
    scope :with_emails, -> { where.not(emails: ['', nil]) }
    scope :with_email, ->(email) { where('emails ILIKE ?', "%#{email}%") }
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

  def string_to_a(str)
    str.to_s.split(',').each(&:strip!)
  end
end

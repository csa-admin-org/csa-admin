# frozen_string_literal: true

module HasEmails
  extend ActiveSupport::Concern

  included do
    attr_accessor :email

    validate :truemails

    scope :with_email, ->(email) { where("lower(emails) LIKE ?", "%#{email.downcase}%") }
    scope :including_email, ->(email) {
      where("(',' || REPLACE(lower(emails), ' ', '') || ',') LIKE ?", "%,#{email.downcase.gsub(/\s+/, '')},%")
    }
  end

  class_methods do
    def find_by_email(email)
      return unless email.present?

      including_email(email).first
    end
  end

  def emails=(emails)
    super string_to_a(emails.downcase).join(", ")
  end

  def emails_array
    string_to_a(emails).sort
  end

  def active_emails
    emails_array.reject { |email| EmailSuppression.outbound.active.exists?(email: email) }
  end

  def emails?
    active_emails.any?
  end

  private

  def truemails
    return unless emails_changed?

    emails_array.each do |email|
      unless Truemail.valid?(email)
        errors.add(:emails, :invalid)
        break
      end
    end
  end

  def string_to_a(str)
    str.to_s.split(",").map { |s| s.gsub(/[[:space:]]/, "") }
  end
end

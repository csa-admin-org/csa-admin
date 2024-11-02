# frozen_string_literal: true

module HasPhones
  extend ActiveSupport::Concern

  included do
    scope :with_phone, ->(phone) { where("lower(phones) LIKE ?", "%#{phone.downcase}%") }
    before_validation :normalize_phones
  end

  def phones_array
    string_to_a(phones)
  end

  private

  def normalize_phones
    return unless phones_changed?

    self[:phones] = phones_array.map { |phone|
      PhonyRails.normalize_number(phone,
        default_country_code: phone_country_code)
    }.join(", ")
  end

  def phone_country_code
    (respond_to?(:country_code) && country_code) ||
      Current.org.country_code
  end

  def string_to_a(str)
    str
      .presence
      .to_s
      .gsub(/[[:space:]]/, "")
      .gsub(/\[/, "")
      .gsub(/\]/, "")
      .gsub(/\"/, "")
      .split(",")
      .map { |s| s.gsub(/[[:space:]]/, "").presence }
      .compact
  end
end

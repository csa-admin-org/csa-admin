module HasPhones
  extend ActiveSupport::Concern

  included do
    scope :with_phone, ->(phone) { where('phones ILIKE ?', "%#{phone}%") }
  end

  def phones=(phones)
    super string_to_a(phones).map { |phone|
      PhonyRails.normalize_number(phone, default_country_code: 'CH')
    }.join(', ')
  end

  def phones_array
    string_to_a(phones)
  end

  private

  def string_to_a(str)
    str
      .presence
      .to_s
      .gsub(/[[:space:]]/, '')
      .split(',')
      .map { |s| s.gsub(/[[:space:]]/, '').presence }
      .compact
  end
end

module HasIBAN
  extend ActiveSupport::Concern

  included do
    normalizes :iban, with: ->(iban) { iban.presence&.gsub(/\s/, "")&.upcase }
  end

  def iban_formatted
    iban&.scan(/.{1,4}/)&.join(" ")
  end
end

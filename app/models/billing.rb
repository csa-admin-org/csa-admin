# frozen_string_literal: true

module Billing
  extend self

  SEPA_CREDITOR_IDENTIFIER_FORMAT = /\A[A-Z]{2}\d{2}[A-Z0-9]{3}[A-Z0-9+?\/:().,'\-]{1,28}\z/i
  SEPA_MANDATE_IDENTIFIER_FORMAT = /\A[A-Za-z0-9\/?:().,'+\- ]{1,35}\z/

  def sepa_creditor_identifier_valid?(identifier)
    identifier = identifier.to_s
    return false unless identifier.match?(SEPA_CREDITOR_IDENTIFIER_FORMAT)
    return identifier.length == 18 if identifier[0, 2].casecmp?("DE")

    true
  end

  def iban_format(country_code = nil)
    case Current.org.country_code
    when "CH"; /\ACH\d{2}3[01]\d{3}[a-z0-9]{12}\z/i # QR IBAN
    when "FR"; /\AFR\d{12}[a-z0-9]{11}\d{2}\z/i
    when "DE"; /\ADE\d{20}\z/i
    when "NL"; /\ANL\d{2}[A-Z]{4}\d{10}\z/i
    end
  end

  def iban_placeholder(country_code = nil)
    case Current.org.country_code
    when "CH"; "CHXX 3XXX XXXX XXXX XXXX X"
    when "FR"; "FRXX XXXX XXXX XXXX XXXX XXXX XXX"
    when "DE"; "DEXX XXXX XXXX XXXX XXXX XX"
    when "NL"; "NLXX XXXX XXXX XXXX XX"
    end
  end

  def reference(country_code = nil)
    Current.org.swiss_qr? ? SwissQRReference : ScorReference
  end

  def import_payments(file)
    if file.content_type == "text/xml"
      CamtFile.process!(file)
    else
      MtFile.process!(file)
    end
  rescue CamtFile::UnsupportedFileError, MtFile::UnsupportedFileError
    false
  end
end

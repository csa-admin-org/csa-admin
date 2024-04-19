module Billing
  extend self

  def iban_format(country_code = nil)
    country_code ||= Current.acp.country_code
    case country_code
    when "CH"; /\ACH\d{2}3[01]\d{3}[a-z0-9]{12}\z/i # QR IBAN
    when "FR"; /\AFR\d{12}[a-z0-9]{11}\d{2}\z/i
    when "DE"; /\ADE\d{20}\z/i
    end
  end

  def iban_placeholder(country_code = nil)
    country_code ||= Current.acp.country_code
    case country_code
    when "CH"; "CHXX 3XXX XXXX XXXX XXXX X"
    when "FR"; "FRXX XXXX XXXX XXXX XXXX XXXX XXX"
    when "DE"; "DEXX XXXX XXXX XXXX XXXX XX"
    end
  end

  def reference(country_code = nil)
    country_code ||= Current.acp.country_code
    case country_code
    when "CH"; SwissQRReference
    else ScorReference
    end
  end

  def import_payments(file)
    Rails.logger.debug "IMPORT PAYMENTS"
    Rails.logger.debug file.content_type
    if file.content_type == "text/xml"
      CamtFile.process!(file)
    else
      MtFile.process!(file)
    end
  rescue CamtFile::UnsupportedFileError, MtFile::UnsupportedFileError
    false
  end
end

class QRReferenceNumber
  LENGTH = 27
  CHECKSUM_SERIES = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5].freeze

  def initialize(invoice_id)
    @invoice_id = invoice_id
  end

  def ref
    @ref ||= add_checksum_digit("#{bank_ref}#{invoice_ref}")
  end

  def formatted_ref
    format_ref(ref)
  end

  private

  def invoice_ref
    ref = @invoice_id.to_s
    ref.prepend('0') until ref.length == invoice_ref_length
    ref
  end

  def invoice_ref_length
    @invoice_ref_length ||= LENGTH - 1 - bank_ref.to_s.length # 1 for check digit
  end

  def bank_ref
    Current.acp.qr_bank_reference
  end

  def format_ref(ref)
    ref
      .delete(' ')
      .reverse
      .gsub(/(.{5})(?=.)/, '\1 \2')
      .reverse
  end

  def add_checksum_digit(string)
    "#{string}#{checksum_digit(string)}"
  end

  def checksum_digit(string)
    string = string.gsub(/\D/, '')
    carry = 0
    string.split(//).each { |char| carry = CHECKSUM_SERIES[(carry + char.to_i) % 10] }
    (10 - carry) % 10
  end
end

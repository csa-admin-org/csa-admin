require 'isr_digit_checker'

class QRReferenceNumber
  include ISRDigitChecker

  REF_LENGHT_WITHOUT_CHECK_DIGIT = 26

  def initialize(invoice_id)
    @invoice_id = invoice_id
  end

  def ref
    @ref ||= check_digit!("#{bank_ref}#{invoice_ref}")
  end

  def formatted_ref
    format_ref(ref)
  end

  private

  def invoice_ref_length
    @invoice_ref_length ||=
      REF_LENGHT_WITHOUT_CHECK_DIGIT - bank_ref.to_s.length
  end

  def invoice_ref
    ref = @invoice_id.to_s
    ref.prepend('0') until ref.length == invoice_ref_length
    ref
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
end

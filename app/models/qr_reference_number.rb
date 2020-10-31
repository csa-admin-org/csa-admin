require 'isr_digit_checker'

class QRReferenceNumber
  include ISRDigitChecker

  ISR_LENGHT_WITHOUT_CHECK_DIGIT = 26

  def initialize(invoice_id)
    @invoice_id = invoice_id
  end

  def ref
    check_digit!(invoice_ref)
  end

  def formatted_ref
    format_ref(ref)
  end

  private

  def invoice_ref
    ref = @invoice_id.to_s
    ref.prepend('0') until ref.length == ISR_LENGHT_WITHOUT_CHECK_DIGIT
    ref
  end

  def format_ref(ref)
    ref
      .delete(' ')
      .reverse
      .gsub(/(.{5})(?=.)/, '\1 \2')
      .reverse
  end
end

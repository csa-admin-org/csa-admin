require 'isr_digit_checker'

class ISRReferenceNumber
  include ISRDigitChecker

  CCP = '01-13734-6'
  IDENDITY = '00 11041 90802 41000'
  CODE = '01' # ISR + CHF

  attr_reader :invoice_id, :amount

  def initialize(invoice_id, amount)
    @invoice_id = invoice_id
    @amount = amount
  end

  def full_ref
    "#{amount_ref}>#{ref.delete(' ')}+ #{ccp_ref}>"
  end

  def ref
    ref = "#{IDENDITY} #{invoice_ref}"
    check_digit!(ref)
  end

  private

  def invoice_ref
    ref = invoice_id.to_s
    ref.prepend('0') while ref.length != 9
    ref.gsub(/(.{5})(?=.)/, '\1 \2')
  end

  def ccp_ref
    CCP.delete('-')
  end

  def amount_ref
    ref = CODE + amount_str
    check_digit!(ref)
  end

  def amount_str
    rounded_amount = '%.2f' % ((amount.round(2) * 20).round / 20.0)
    rounded_amount.to_s.delete('.').tap do |ref|
      ref.prepend('0') while ref.length != 10
    end
  end
end

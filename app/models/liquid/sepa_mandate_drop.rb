# frozen_string_literal: true

class Liquid::SEPAMandateDrop < Liquid::Drop
  def initialize(mandate)
    @mandate = mandate
  end

  def umr
    @mandate.umr
  end

  def signed_on
    I18n.l(@mandate.signed_on)
  end

  def masked_iban
    @mandate.masked_iban
  end
end

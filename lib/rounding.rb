module Rounding
  # round a given number to the nearest step
  def round_to_five_cents
    ((round(2) * 20).round / BigDecimal(20))
  end
end

class Numeric; include Rounding end

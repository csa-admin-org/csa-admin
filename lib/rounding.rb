class Numeric
  # round a given number to the nearest step
  def round_to_five_cents
    ((round(2) * 20).round / BigDecimal(20))
  end
end

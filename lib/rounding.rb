class Numeric
  # round a given number to the nearest step
  def round_to_five_cents
    ((round(2) * 20).round / 20.0)
  end
end

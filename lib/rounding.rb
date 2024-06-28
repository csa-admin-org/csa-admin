# frozen_string_literal: true

module Rounding
  def round_to_five_cents
    (to_d * 20).round(0, :half_up) / 20
  end

  def round_to_one_cent
    to_d.round(2, :half_up)
  end
end

class Numeric; include Rounding end

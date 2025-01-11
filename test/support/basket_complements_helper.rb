# frozen_string_literal: true

module BasketComplementsHelper
  def bread_id; basket_complements(:bread).id end
  def cheese_id; basket_complements(:cheese).id end
  def eggs_id; basket_complements(:eggs).id end
end

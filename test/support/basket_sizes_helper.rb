# frozen_string_literal: true

module BasketSizesHelper
  def small_id; basket_sizes(:small).id; end
  def medium_id; basket_sizes(:medium).id; end
  def large_id; basket_sizes(:large).id; end
end

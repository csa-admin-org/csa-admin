# frozen_string_literal: true

module DeliveryCyclesHelper
  def mondays_id; delivery_cycles(:mondays).id end
  def thursdays_id; delivery_cycles(:thursdays).id end
  def all_id; delivery_cycles(:all).id end

  def create_delivery_cycle(attributes = {})
    DeliveryCycle.create!({
      name: "Cycle"
    }.merge(attributes))
  end
end

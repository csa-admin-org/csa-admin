# frozen_string_literal: true

module DepotsHelper
  def farm_id; depots(:farm).id end
  def home_id; depots(:home).id end
  def bakery_id; depots(:bakery).id end
end

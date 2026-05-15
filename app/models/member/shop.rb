# frozen_string_literal: true

module Member::Shop
  extend ActiveSupport::Concern

  included do
    belongs_to :shop_depot, class_name: "Depot", optional: true
    belongs_to :shop_delivery_cycle, class_name: "DeliveryCycle", optional: true

    before_validation :clear_shop_delivery_cycle_without_depot

    validates :shop_depot, inclusion: { in: proc { Depot.all }, allow_nil: true }
    validates :shop_depot_id, presence: true,
      on: :create,
      if: -> { public_create && Current.org.member_form_mode == "shop" && Depot.visible.exists? }
    validates :shop_delivery_cycle, inclusion: { in: proc { DeliveryCycle.all }, allow_nil: true }
  end

  def shop_depot
    use_shop_depot? ? super : current_or_future_membership&.depot
  end

  def use_shop_depot?
    shop_depot_id? && current_or_future_membership.nil?
  end

  private

  def clear_shop_delivery_cycle_without_depot
    self.shop_delivery_cycle_id = nil unless shop_depot_id?
  end
end

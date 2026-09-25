# frozen_string_literal: true

class AllowRepeatedShopOrderGroupPeriods < ActiveRecord::Migration[8.1]
  def up
    return unless index_exists?(:shop_order_groups, [ :member_id, :period ], unique: true, name: "index_shop_order_groups_on_member_id_and_period")

    remove_index :shop_order_groups, name: "index_shop_order_groups_on_member_id_and_period"
    add_index :shop_order_groups, [ :member_id, :period ], name: "index_shop_order_groups_on_member_id_and_period"
  end

  def down
  end
end

class ImproveBasketContents < ActiveRecord::Migration[6.1]
  def change
    add_column :basket_contents, :basket_quantities, :decimal, precision: 8, scale: 2, array: true, null: false, default: []
    add_column :basket_contents, :baskets_counts, :integer, array: true, null: false, default: []
    add_column :basket_contents, :basket_size_ids, :integer, array: true, null: false, default: []

    small = BasketSize.paid.first
    big = BasketSize.paid.last
    BasketContent.find_each do |bc|
      ids = []
      ids << small.id if bc[:basket_sizes].include?('small')
      ids << big.id if bc[:basket_sizes].include?('big')
      quantities = []
      counts = []
      ids.sort.each do |id|
        case id.to_i
        when small.id
          quantities << bc.small_basket_quantity
          counts << bc.small_baskets_count
        when big.id
          quantities << bc.big_basket_quantity
          counts << bc.big_baskets_count
        end
      end
      bc.update_columns(
        basket_size_ids: ids,
        basket_quantities: quantities,
        baskets_counts: counts)
    end
  end
end

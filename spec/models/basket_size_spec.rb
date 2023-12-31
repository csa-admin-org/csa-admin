require "rails_helper"

describe BasketSize do
  def member_ordered_names
    BasketSize.member_ordered.map(&:name)
  end

  specify "#member_ordered" do
    small_size = create(:basket_size, price: 10, name: "petit")
    create(:basket_size, price: 20, name: "moyen", public_name: "")
    create(:basket_size, price: 30, name: "grand")

    expect(member_ordered_names).to eq %w[grand moyen petit]

    Current.acp.update! basket_sizes_member_order_mode: "price_asc"
    expect(member_ordered_names).to eq %w[petit moyen grand]

    Current.acp.update! basket_sizes_member_order_mode: "name_asc"
    expect(member_ordered_names).to eq %w[grand moyen petit]

    small_size.update! member_order_priority: 0
    expect(member_ordered_names).to eq %w[petit grand moyen]
  end
end

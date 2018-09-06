require 'rails_helper'

describe BasketsBasketComplement do
  it 'validates that price is zero when basket complement has an annual price type' do
    membership = create(:membership)
    membership.reload
    basket_complement = create(:basket_complement, :annual_price_type, id: 1, deliveries_count: 40)
    membership.update!(memberships_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, price: '', quantity: 1 }
    })
    bbc = membership.baskets.last.baskets_basket_complements.first
    expect(bbc.price).to be_zero

    bbc.update(price: 42)

    expect(bbc).not_to have_valid(:price)
  end
end

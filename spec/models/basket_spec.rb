require 'rails_helper'

describe Basket do
  it 'sets prices on creation' do
    basket = create(:basket,
      basket_size: create(:basket_size, price: 30),
      distribution: create(:distribution, price: 5))

    expect(basket.basket_price).to eq 30
    expect(basket.distribution_price).to eq 5
  end

  it 'updates price when other prices change' do
    basket = create(:basket,
      basket_size: create(:basket_size, price: 30),
      distribution: create(:distribution, price: 5))

    basket.update!(basket_size_id: create(:basket_size, price: 35).id)
    expect(basket.basket_price).to eq(35)

    basket.update!(distribution: create(:distribution, price: 2))
    expect(basket.distribution_price).to eq(2)
  end
end

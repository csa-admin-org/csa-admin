require 'rails_helper'

describe BasketContent do
  describe '#set_basket_quantities' do
    before {
      delivery = create(:delivery)
      create(:basket_size, :small, annual_price: 925)
      create(:basket_size, :big, annual_price: 1330)
    }

    it 'splits pieces to both baskets' do
      basket_content = create(:basket_content,
        quantity: 150,
        unit: 'pièce',
        small_baskets_count: 100,
        big_baskets_count: 50
      )
      expect(basket_content.small_basket_quantity).to eq 1
      expect(basket_content.big_basket_quantity).to eq 1
      expect(basket_content.lost_quantity).to be_zero
    end

    it 'splits pieces with more to big baskets' do
      basket_content = create(:basket_content,
        quantity: 200,
        unit: 'pièce',
        small_baskets_count: 100,
        big_baskets_count: 50
      )
      expect(basket_content.small_basket_quantity).to eq 1
      expect(basket_content.big_basket_quantity).to eq 2
      expect(basket_content.lost_quantity).to be_zero
    end

    it 'gives all pieces to small baskets' do
      basket_content = create(:basket_content,
        quantity: 200,
        unit: 'pièce',
        small_baskets_count: 100,
        big_baskets_count: 0
      )
      expect(basket_content.small_basket_quantity).to eq 2
      expect(basket_content.big_basket_quantity).to be_zero
      expect(basket_content.lost_quantity).to be_zero
    end

    it 'splits kilogramme to both baskets' do
      basket_content = create(:basket_content,
        quantity: 83,
        unit: 'kilogramme',
        small_baskets_count: 131,
        big_baskets_count: 29
      )
      expect(basket_content.small_basket_quantity.to_f).to eq 0.48
      expect(basket_content.big_basket_quantity.to_f).to eq 0.69
      expect(basket_content.lost_quantity.to_f).to eq 0.11
    end

    it 'splits kilogramme to both baskets and splits remaining to big baskets' do
      basket_content = create(:basket_content,
        quantity: 34,
        unit: 'kilogramme',
        small_baskets_count: 151,
        big_baskets_count: 29
      )
      expect(basket_content.small_basket_quantity.to_f).to eq 0.170
      expect(basket_content.big_basket_quantity.to_f).to eq 0.280
      expect(basket_content.lost_quantity.to_f).to eq 0.21
    end

    it 'splits kilogramme to both baskets (2)' do
      basket_content = create(:basket_content,
        quantity: 100,
        unit: 'kilogramme',
        small_baskets_count: 131,
        big_baskets_count: 29
      )
      expect(basket_content.small_basket_quantity.to_f).to eq 0.57
      expect(basket_content.big_basket_quantity.to_f).to eq 0.87
      expect(basket_content.lost_quantity.to_f).to eq 0.1
    end

    it 'splits kilogramme equaly between both baskets' do
      basket_content = create(:basket_content,
        quantity: 160,
        unit: 'kilogramme',
        small_baskets_count: 131,
        big_baskets_count: 29,
        same_basket_quantities: '1'
      )

      expect(basket_content.small_basket_quantity.to_f).to eq 1
      expect(basket_content.big_basket_quantity.to_f).to eq 1
      expect(basket_content.lost_quantity.to_f).to be_zero
    end

    it 'gives all kilogramme to big baskets' do
      basket_content = create(:basket_content,
        quantity: 83,
        unit: 'kilogramme',
        small_baskets_count: 0,
        big_baskets_count: 29
      )
      expect(basket_content.small_basket_quantity.to_f).to be_zero
      expect(basket_content.big_basket_quantity.to_f).to eq 2.86
      expect(basket_content.lost_quantity.to_f).to eq 0.06
    end
  end
end

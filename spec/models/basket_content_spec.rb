require 'rails_helper'

describe BasketContent do
  let(:delivery) { create(:delivery) }
  let(:depot) { create(:depot) }

  def setup(data)
    [data].flatten.each do |attrs|
      quantity = attrs.delete(:quantity)
      basket = create(:basket_size, attrs)
      create(:membership,
        depot: depot,
        basket_size: basket,
        basket_quantity: quantity)
    end
  end

  describe 'validations' do
    it 'validates basket_sizes presence' do
      basket_content = BasketContent.new(basket_size_ids_percentages: {})
      expect(basket_content).not_to have_valid(:basket_size_ids)
    end

    it 'validates percentages' do
      basket_content = BasketContent.new(basket_size_ids_percentages: {
        1001 => 50,
        1002 => 51
      })
      expect(basket_content).not_to have_valid(:basket_percentages)
    end

    it 'validates enough quantity' do
      setup(id: 1001, quantity: 100)
      basket_content = build(:basket_content,
        basket_size_ids_percentages: { 1001 => 100 },
        quantity: 99,
        unit: 'pc')

      expect(basket_content).not_to have_valid(:quantity)
    end
  end

  describe '#set_basket_quantities' do
    it 'splits pieces to both baskets' do
      setup [
        { id: 1001, quantity: 100, price: 1 },
        { id: 1002, quantity: 50, price: 1.5 }
      ]
      basket_content = create(:basket_content,
        quantity: 150,
        unit: 'pc')

      expect(basket_content.basket_quantities).to eq [1, 1]
      expect(basket_content.surplus_quantity).to be_zero
    end

    it 'splits pieces with more to big baskets' do
      setup [
        { id: 1001, quantity: 100, price: 1 },
        { id: 1002, quantity: 50, price: 1.5 }
      ]
      basket_content = create(:basket_content,
        quantity: 200,
        unit: 'pc')

      expect(basket_content.basket_quantities).to eq [1, 2]
      expect(basket_content.surplus_quantity).to be_zero
    end

    it 'gives all pieces to small baskets' do
      setup [
        { id: 1001, quantity: 100, price: 1 },
        { id: 1002, quantity: 50, price: 1.5 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 100,
          1002 => 0
        },
        quantity: 200,
        unit: 'pc')

      expect(basket_content.basket_quantities).to eq [2]
      expect(basket_content.basket_quantity(BasketSize.new(id: 1002))).to be_nil
      expect(basket_content.surplus_quantity).to be_zero
    end

    it 'splits kilogramme to both baskets' do
      setup [
        { id: 1001, quantity: 131, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        quantity: 83,
        unit: 'kg')

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [0.48, 0.69]
      expect(basket_content.surplus_quantity.to_f).to eq 0.11
    end

    it 'splits kilogramme to both baskets (2)' do
      setup [
        { id: 1001, quantity: 131, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        quantity: 100,
        unit: 'kg')

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [0.58, 0.82]
      expect(basket_content.surplus_quantity.to_f).to eq 0.24
    end

    it 'splits kilogramme to both baskets (3)' do
      setup [
        { id: 1001, quantity: 151, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        quantity: 34,
        unit: 'kg')

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [0.17, 0.27]
      expect(basket_content.surplus_quantity.to_f).to eq 0.5
    end

    it 'splits kilogramme equaly between both baskets' do
      setup [
        { id: 1001, quantity: 131, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 50,
          1002 => 50
        },
        quantity: 320,
        unit: 'kg')

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [2, 2]
      expect(basket_content.surplus_quantity.to_f).to be_zero
    end

    it 'gives all kilogramme to big baskets' do
      setup [
        { id: 1001, quantity: 131, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 0,
          1002 => 100
        },
        quantity: 83,
        unit: 'kg')

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [2.86]
      expect(basket_content.basket_quantity(BasketSize.new(id: 1001))).to be_nil
      expect(basket_content.surplus_quantity.to_f).to eq 0.06
    end

    specify 'with 3 basket sizes' do
      setup [
        { id: 1002, quantity: 50, price: 33 },
        { id: 1005, quantity: 100, price: 23 },
        { id: 1003, quantity: 20, price: 44 }
      ]
      basket_content = create(:basket_content,
        quantity: 100,
        unit: 'kg')

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [0.68, 0.9, 0.48]
      expect(basket_content.surplus_quantity.to_f).to be_zero
    end
  end
end

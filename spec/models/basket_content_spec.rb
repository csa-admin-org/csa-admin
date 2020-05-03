require 'rails_helper'

describe BasketContent do
  before do
    create(:delivery)
    depot = create(:depot)
    small = create(:basket_size, :small)
    big = create(:basket_size, :big)
    @membership_small = create(:membership,
      depot: depot,
      basket_size: small,
      basket_quantity: 100)
    @membership_big =  create(:membership,
      depot: depot,
      basket_size: big,
      basket_quantity: 50)
  end

  def set_small_quantity(quantity)
    @membership_small.baskets.first.update!(quantity: quantity)
  end

  def set_big_quantity(quantity)
    @membership_big.baskets.first.update!(quantity: quantity)
  end

  describe 'validations' do
    it 'validates basket_sizes presence' do
      basket_content = BasketContent.new(basket_sizes: [''])

      expect(basket_content).not_to have_valid(:basket_sizes)
    end

    it 'validates enough quantity' do
      basket_content = build(:basket_content,
        quantity: 99,
        unit: 'pièce',
        small_baskets_count: 100,
        big_baskets_count: 50)

      expect(basket_content).not_to have_valid(:quantity)
    end
  end

  describe '#set_basket_quantities' do
    it 'splits pieces to both baskets' do
      basket_content = create(:basket_content,
        quantity: 150,
        unit: 'pièce')

      expect(basket_content.small_basket_quantity).to eq 1
      expect(basket_content.big_basket_quantity).to eq 1
      expect(basket_content.surplus_quantity).to be_zero
    end

    it 'splits pieces with more to big baskets' do
      basket_content = create(:basket_content,
        quantity: 200,
        unit: 'pièce')

      expect(basket_content.small_basket_quantity).to eq 1
      expect(basket_content.big_basket_quantity).to eq 2
      expect(basket_content.surplus_quantity).to be_zero
    end

    it 'gives all pieces to small baskets' do
      basket_content = create(:basket_content,
        basket_sizes: %w[small],
        quantity: 200,
        unit: 'pièce')

      expect(basket_content.small_basket_quantity).to eq 2
      expect(basket_content.big_basket_quantity).to be_zero
      expect(basket_content.surplus_quantity).to be_zero
    end

    it 'splits kilogramme to both baskets' do
      set_small_quantity(131)
      set_big_quantity(29)
      basket_content = create(:basket_content,
        quantity: 83,
        unit: 'kilogramme')

      expect(basket_content.small_basket_quantity.to_f).to eq 0.48
      expect(basket_content.big_basket_quantity.to_f).to eq 0.69
      expect(basket_content.surplus_quantity.to_f).to eq 0.11
    end

    it 'splits kilogramme to both baskets and splits remaining to big baskets' do
      set_small_quantity(151)
      set_big_quantity(29)
      basket_content = create(:basket_content,
        quantity: 34,
        unit: 'kilogramme')

      expect(basket_content.small_basket_quantity.to_f).to eq 0.170
      expect(basket_content.big_basket_quantity.to_f).to eq 0.280
      expect(basket_content.surplus_quantity.to_f).to eq 0.21
    end

    it 'splits kilogramme to both baskets (2)' do
      set_small_quantity(131)
      set_big_quantity(29)
      basket_content = create(:basket_content,
        quantity: 100,
        unit: 'kilogramme')

      expect(basket_content.small_basket_quantity.to_f).to eq 0.57
      expect(basket_content.big_basket_quantity.to_f).to eq 0.87
      expect(basket_content.surplus_quantity.to_f).to eq 0.1
    end

    it 'splits kilogramme equaly between both baskets' do
      set_small_quantity(131)
      set_big_quantity(29)
      basket_content = create(:basket_content,
        quantity: 320,
        unit: 'kilogramme',
        same_basket_quantities: '1')

      expect(basket_content.small_basket_quantity.to_f).to eq 2
      expect(basket_content.big_basket_quantity.to_f).to eq 2
      expect(basket_content.surplus_quantity.to_f).to be_zero
    end

    it 'gives all kilogramme to big baskets' do
      set_big_quantity(29)
      basket_content = create(:basket_content,
        basket_sizes: %w[big],
        quantity: 83,
        unit: 'kilogramme')

      expect(basket_content.small_basket_quantity.to_f).to be_zero
      expect(basket_content.big_basket_quantity.to_f).to eq 2.86
      expect(basket_content.surplus_quantity.to_f).to eq 0.06
    end
  end
end

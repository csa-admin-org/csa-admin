require 'rails_helper'

describe BasketSize do
  describe '#deliveries_count' do
    it 'counts future deliveries when exits' do
      basket_size = create(:basket_size)

      create(:delivery)
      create(:delivery)

      expect(basket_size.deliveries_count).to eq 2

      create(:delivery, date: 1.year.from_now)

      expect(basket_size.deliveries_count).to eq 1
    end
  end
end

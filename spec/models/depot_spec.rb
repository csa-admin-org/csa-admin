require 'rails_helper'

describe Depot do
  describe '#deliveries_count' do
    it 'counts future deliveries when exits' do
      create_deliveries(2)
      depot = create(:depot)

      expect { create(:delivery, date: 1.year.from_now) }
        .to change { depot.reload.deliveries_counts }.from([2]).to([1])
    end
  end
end

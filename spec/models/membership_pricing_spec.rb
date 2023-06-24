require 'rails_helper'

describe MembershipPricing do
  before do
    create(:basket_size, id: 1, price: 10)
    create(:basket_size, id: 2, price: 15)
  end

  def pricing(params = {})
    MembershipPricing.new(params)
  end

  specify 'with no params' do
    expect(pricing.prices).to eq [0]
  end

  specify 'simple pricing' do
    create_deliveries(3)
    create(:depot, id: 1)

    expect(pricing).not_to be_present

    pricing = pricing(waiting_depot_id: 1)
    expect(pricing).not_to be_present
  end

  specify 'with depot price' do
    create_deliveries(3)
    create(:depot, id: 1, price: 1)
    create(:depot, id: 2, price: 2)

    pricing = pricing(waiting_basket_size_id: 1)
    expect(pricing.prices).to eq [3 * 10]

    pricing = pricing(waiting_basket_size_id: 2)
    expect(pricing.prices).to eq [3 * 15]

    pricing = pricing(waiting_depot_id: 1)
    expect(pricing.prices).to eq [3 * 1]

    pricing = pricing(waiting_depot_id: 2)
    expect(pricing.prices).to eq [3 * 2]

    pricing = pricing(waiting_basket_size_id: 1, waiting_depot_id: 1)
    expect(pricing.prices).to eq [3 * (10 + 1)]

    pricing = pricing(waiting_basket_size_id: 1, waiting_depot_id: 2)
    expect(pricing.prices).to eq [3 * (10 + 2)]

    pricing = pricing(waiting_basket_size_id: 2, waiting_depot_id: 2)
    expect(pricing.prices).to eq [3 * (15 + 2)]
  end

  specify 'with price_extra' do
    Current.acp.update! features: ['basket_price_extra']
    create_deliveries(3)
    create(:depot)

    pricing = pricing(waiting_basket_size_id: 1, waiting_basket_price_extra: "2")
    expect(pricing.prices).to eq [3 * (10 + 2)]
  end

  specify 'with multiple deliveries cycles' do
    create_deliveries(5)
    depot = create(:depot, id: 1)
    create(:depot, id: 2)

    create(:deliveries_cycle, :visible, id: 2, results: :odd, depots: [depot])
    create(:deliveries_cycle, :visible, id: 3, results: :all, depots: Depot.all)

    pricing = pricing(waiting_basket_size_id: 1)
    expect(pricing.prices).to eq [3 * 10, 5 * 10]

    pricing = pricing(waiting_basket_size_id: 1, waiting_depot_id: 2)
    expect(pricing.prices).to eq [5 * 10]

    pricing = pricing(
      waiting_basket_size_id: 1,
      waiting_depot_id: 1,
      waiting_deliveries_cycle_id: 2)
    expect(pricing.prices).to eq [3 * 10]
  end

  specify 'complements pricing' do
    create_deliveries(3)
    create(:depot, id: 1)

    create(:basket_complement,
      id: 1,
      price: 3,
      delivery_ids: Delivery.all.pluck(:id))
    create(:basket_complement,
      id: 2,
      price: 4,
      delivery_ids: Delivery.limit(2).pluck(:id))
    create(:basket_complement, :annual_price_type,
      id: 3,
      price: 100,
      delivery_ids: Delivery.all.pluck(:id))

    pricing = pricing(members_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, quantity: 1 },
    })
    expect(pricing.prices).to eq [3 * 3]

    pricing = pricing(members_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, quantity: 2 },
    })
    expect(pricing.prices).to eq [2 * 3 * 3]

    pricing = pricing(members_basket_complements_attributes: {
      '0' => { basket_complement_id: 2, quantity: 1 },
    })
    expect(pricing.prices).to eq [2 * 4]

    pricing = pricing(members_basket_complements_attributes: {
      '0' => { basket_complement_id: 3, quantity: 2 },
    })
    expect(pricing.prices).to eq [2 * 100]

    create(:deliveries_cycle, :visible, id: 2, results: :odd, depots: Depot.all)
    create(:deliveries_cycle, :visible, id: 3, results: :all, depots: Depot.all)

    pricing = pricing(members_basket_complements_attributes: {
      '0' => { basket_complement_id: 1, quantity: 1 },
    })
    expect(pricing.prices).to eq [2 * 3, 3 * 3]

    pricing = pricing(
      waiting_deliveries_cycle_id: 2,
      members_basket_complements_attributes: {
        '0' => { basket_complement_id: 1, quantity: 1 },
      })
    expect(pricing.prices).to eq [2 * 3]
  end
end

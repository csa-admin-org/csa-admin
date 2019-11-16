require 'rails_helper'

describe GroupBuying::Order do
  it 'validates member presence' do
    order = described_class.new(member_id: nil)
    expect(order).not_to have_valid(:member)
  end

  it 'validates delivery presence' do
    order = described_class.new(delivery_id: nil)
    expect(order).not_to have_valid(:delivery)
  end

  it 'validates items presence' do
    order = described_class.new(items: [])
    expect(order).not_to have_valid(:base)
    expect(order.errors[:base]).to include('Aucun produit sélectionné')
  end

  it 'validates terms_of_service acceptance' do
    current_acp.update!(group_buying_terms_of_service_url: 'https://foo.pdf')
    order = described_class.new(items: [])
    expect(order).not_to have_valid(:base)
    expect(order.errors[:base])
      .to include('Les conditions générales de vente doivent être acceptées')
  end

  it 'does not validate terms_of_service acceptance without them defined' do
    current_acp.update!(group_buying_terms_of_service_url: nil)
    order = described_class.new(items: [])
    order.validate
    expect(order.errors[:base])
      .not_to include('Les conditions générales de vente doivent être acceptées')
  end

  it 'creates a valid order and copies items prices' do
    product = create(:group_buying_product, price: 42.42)
    member = create(:member)
    delivery = create(:group_buying_delivery)

    order = described_class.create!(
      terms_of_service: '1',
      member: member,
      delivery: delivery,
      items_attributes: {
        '0' => {
          product_id: product.id,
          quantity: 2
        }
      })
    expect(order.items_count).to eq 1
    expect(order.amount).to eq 84.84
    expect(order.items.first).to have_attributes(
      product: product,
      quantity: 2,
      price: 42.42)
  end
end

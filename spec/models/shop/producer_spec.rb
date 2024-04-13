require "rails_helper"

describe Shop::Producer do
  specify "find null producer" do
    producer = Shop::Producer.find("null")
    expect(producer).to eq Shop::NullProducer.instance
  end

  specify "can discard / delete" do
    producer = create(:shop_producer)

    expect(producer.can_delete?).to eq true
    expect(producer.can_discard?).to eq false

    product = create(:shop_product, producer: producer)
    producer.reload

    expect(producer.can_delete?).to eq false
    expect(producer.can_discard?).to eq false

    product.discard
    producer.reload

    expect(producer.can_delete?).to eq false
    expect(producer.can_discard?).to eq true

    expect {
      producer.destroy
    }.to change { producer.discarded_at }.from(nil)
    expect(producer).to be_discarded
  end
end

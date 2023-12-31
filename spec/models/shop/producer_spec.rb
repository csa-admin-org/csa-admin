require "rails_helper"

describe Shop::Producer do
  specify "find null producer" do
    producer = Shop::Producer.find("null")
    expect(producer).to eq Shop::NullProducer.instance
  end
end

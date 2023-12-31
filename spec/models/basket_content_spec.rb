require "rails_helper"

describe BasketContent do
  let(:delivery) { create(:delivery) }
  let(:depot) { create(:depot) }

  def setup(data)
    [ data ].flatten.each do |attrs|
      quantity = attrs.delete(:quantity)
      basket = create(:basket_size, attrs)
      create(:membership,
        depot: depot,
        basket_size: basket,
        basket_quantity: quantity)
    end
  end

  describe "validations" do
    it "validates basket_sizes presence" do
      basket_content = BasketContent.new(basket_size_ids_percentages: {})
      expect(basket_content).not_to have_valid(:basket_size_ids)
    end

    it "validates percentages" do
      basket_content = BasketContent.new(basket_size_ids_percentages: {
        1001 => 50,
        1002 => 51
      })
      expect(basket_content).not_to have_valid(:basket_percentages)
    end

    it "validates enough quantity" do
      setup(id: 1001, quantity: 100)
      basket_content = build(:basket_content,
        basket_size_ids_percentages: { 1001 => 100 },
        quantity: 99,
        unit: "pc")

      expect(basket_content).not_to have_valid(:quantity)
      expect(basket_content.errors[:quantity]).to eq [ "Insuffisante" ]
    end

    it "validates enough quantity with miss piece" do
      setup(id: 1001, quantity: 100)
      basket_content = build(:basket_content,
        basket_size_ids_quantities: { 1001 => 1 },
        quantity: 99,
        unit: "pc")

      expect(basket_content).not_to have_valid(:quantity)
      expect(basket_content.errors[:quantity]).to eq [ "Insuffisante (manque 1p)" ]
    end
  end

  describe "#set_distribution_mode" do
    before do
      setup [
        { id: 1001, quantity: 1, price: 1 },
        { id: 1002, quantity: 1, price: 1 }
      ]
    end

    specify "set automatic mode by default" do
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 50,
          1002 => 50
        },
        quantity: 150,
        unit: "pc")

      expect(basket_content.distribution_mode).to eq "automatic"
    end

    specify "set manual mode when quantities present" do
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 50,
          1002 => 50
        },
        basket_size_ids_quantities: {
          1001 => 75,
          1002 => 75
        },
        quantity: 150,
        unit: "pc")

      expect(basket_content.distribution_mode).to eq "manual"
    end
  end

  describe "#set_basket_quantities_automatically" do
    it "splits pieces to both baskets" do
      setup [
        { id: 1001, quantity: 100, price: 1 },
        { id: 1002, quantity: 50, price: 1.5 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        quantity: 150,
        unit: "pc")

      expect(basket_content.basket_quantities).to eq [ 1, 1 ]
      expect(basket_content.surplus_quantity).to be_zero
    end

    it "splits pieces with more to big baskets" do
      setup [
        { id: 1001, quantity: 100, price: 1 },
        { id: 1002, quantity: 50, price: 1.5 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        quantity: 200,
        unit: "pc")

      expect(basket_content.basket_quantities).to eq [ 1, 2 ]
      expect(basket_content.surplus_quantity).to be_zero
    end

    it "gives all pieces to small baskets" do
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
        unit: "pc")

      expect(basket_content.basket_quantities).to eq [ 2 ]
      expect(basket_content.basket_quantity(BasketSize.new(id: 1002))).to be_nil
      expect(basket_content.surplus_quantity).to be_zero
    end

    it "splits kilogramme to both baskets" do
      setup [
        { id: 1001, quantity: 131, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 41,
          1002 => 59
        },
        quantity: 83,
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 0.48, 0.693 ]
      expect(basket_content.surplus_quantity.to_f).to eq 0.02
    end

    it "splits kilogramme to both baskets (2)" do
      setup [
        { id: 1001, quantity: 131, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 41,
          1002 => 59
        },
        quantity: 100,
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 0.579, 0.832 ]
      expect(basket_content.surplus_quantity.to_f).to eq 0.02
    end

    it "splits kilogramme to both baskets (3)" do
      setup [
        { id: 1001, quantity: 151, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 41,
          1002 => 59
        },
        quantity: 34,
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 0.176, 0.255 ]
      expect(basket_content.surplus_quantity.to_f).to eq 0.03
    end

    it "splits kilogramme equaly between both baskets" do
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
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 2, 2 ]
      expect(basket_content.surplus_quantity.to_f).to be_zero
    end

    it "gives all kilogramme to big baskets" do
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
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 2.862 ]
      expect(basket_content.basket_quantity(BasketSize.new(id: 1001))).to be_nil
      expect(basket_content.surplus_quantity.to_f).to be_zero
    end

    specify "with 3 basket sizes" do
      setup [
        { id: 1005, quantity: 100, price: 23 },
        { id: 1002, quantity: 50, price: 33 },
        { id: 1003, quantity: 20, price: 44 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_percentages: {
          1005 => 23,
          1002 => 33,
          1003 => 44
        },
        quantity: 100,
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 0.476, 0.684, 0.91 ]
      expect(basket_content.surplus_quantity.to_f).to be_zero
    end
  end

  describe "#set_basket_quantities_automatically" do
    specify "gives all kilogramme to big baskets" do
      setup [
        { id: 1001, quantity: 131, price: 23 },
        { id: 1002, quantity: 29, price: 33 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_quantities: {
          1001 => 0,
          1002 => 2500
        },
        quantity: 83,
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 2.5 ]
      expect(basket_content.basket_quantity(BasketSize.new(id: 1001))).to be_nil
      expect(basket_content.surplus_quantity.to_f).to eq 10.5
    end

    specify "with 3 basket sizes" do
      setup [
        { id: 1005, quantity: 100, price: 23 },
        { id: 1002, quantity: 50, price: 33 },
        { id: 1003, quantity: 20, price: 44 }
      ]
      basket_content = create(:basket_content,
        basket_size_ids_quantities: {
          1005 => 500,
          1002 => 600,
          1003 => 900
        },
        quantity: 100,
        unit: "kg")

      expect(basket_content.basket_quantities.map(&:to_f)).to eq [ 0.5, 0.6, 0.9 ]
      expect(basket_content.surplus_quantity.to_f).to eq 2.0
    end
  end

  describe "Delivery#update_basket_content_avg_prices!", freeze: "2022-04-18" do
    before {
      setup [
        { id: 1001, quantity: 1, price: 20 },
        { id: 1002, quantity: 1, price: 30 }
      ]
    }

    let(:delivery) { create(:delivery) }
    let(:depot) { create(:depot) }
    let(:basket_size_1) { BasketSize.find(1001) }
    let(:basket_size_2) { BasketSize.find(1002) }

    specify "with all depots content", sidekiq: :inline do
      expect {
        create(:basket_content,
          basket_size_ids_percentages: {
            1001 => 40,
            1002 => 60
          },
          delivery: delivery,
          quantity: 100,
          unit: "pc",
          unit_price: 2)
      }.to change { delivery.reload.basket_content_avg_prices }

      expect(delivery.basket_content_avg_prices).to eq(
        "1001" => 78.0,
        "1002" => 122.0)
      expect(delivery.basket_content_yearly_price_diffs).to eq(
        1001 => { DeliveryCycle.first => 58.0 },
        1002 => { DeliveryCycle.first => 92.0 })
      expect(delivery.basket_content_prices).to eq(
        basket_size_1 => { depot => 78.0 },
        basket_size_2 => { depot => 122.0 })
    end

    specify "with different depots content", sidekiq: :inline do
      other_depot = create(:depot)
      create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        delivery: delivery,
        quantity: 100,
        unit: "pc",
        unit_price: 2,
        depot_ids: [ depot.id ])

      expect(delivery.basket_content_avg_prices).to eq(
        "1001" => 78.0,
        "1002" => 122.0)
      expect(delivery.basket_content_prices).to eq(
        basket_size_1 => {
          depot => 78.0 },
        basket_size_2 => {
          depot => 122.0
        })
    end

    specify "with all in one basket_size", sidekiq: :inline do
      create(:basket_content,
        delivery: delivery,
        basket_size_ids_percentages: {
          1001 => 0,
          1002 => 100
        },
        quantity: 100,
        unit: "pc",
        unit_price: 2)

      expect(delivery.basket_content_avg_prices).to eq(
        "1002" => 200.0)
      expect(delivery.basket_content_prices).to eq(
        basket_size_1 => {},
        basket_size_2 => { depot => 200.0 })
    end

    specify "with other delivery basket content", sidekiq: :inline do
      other_delivery = create(:delivery)
      create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        delivery: other_delivery,
        quantity: 100,
        unit: "kg",
        unit_price: 1)
      create(:basket_content,
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        delivery: delivery,
        quantity: 100,
        unit: "pc",
        unit_price: 2)

      expect(other_delivery.basket_content_avg_prices).to eq(
        "1001" => 40.0,
        "1002" => 60.0)
      expect(delivery.basket_content_avg_prices).to eq(
        "1001" => 78.0,
        "1002" => 122.0)
      expect(delivery.basket_content_yearly_price_diffs)
        .not_to eq(other_delivery.basket_content_yearly_price_diffs)
      expect(other_delivery.basket_content_yearly_price_diffs).to eq(
        1001 => { DeliveryCycle.first => 20.0 },
        1002 => { DeliveryCycle.first => 30.0 })
      expect(delivery.basket_content_yearly_price_diffs).to eq(
        1001 => { DeliveryCycle.first => 78.0 },
        1002 => { DeliveryCycle.first => 122.0 })
    end
  end

  describe ".duplicate_all" do
    before do
      setup [
        { id: 1001, quantity: 1, price: 20 },
        { id: 1002, quantity: 1, price: 30 }
      ]
    end

    specify "copies all basket content from one delivery to another" do
      from_delivery = create(:delivery)
      to_delivery = create(:delivery)
      create(:basket_content,
        delivery: from_delivery,
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        quantity: 100,
        unit: "kg",
        unit_price: 1)
      create(:basket_content,
        delivery: from_delivery,
        basket_size_ids_quantities: {
          1001 => 75,
          1002 => 75
        },
        quantity: 150,
        unit: "pc")

      expect {
        BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
      }.to change { to_delivery.basket_contents.count }.by(2)

      expect(to_delivery.basket_contents.first).to have_attributes(
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        quantity: 100,
        unit: "kg",
        unit_price: 1)
      expect(to_delivery.basket_contents.last).to have_attributes(
        basket_size_ids_quantities: {
          1001 => 75,
          1002 => 75
        },
        quantity: 150,
        unit: "pc")
    end

    specify "do nothing when deliveries has no contents" do
      from_delivery = create(:delivery)
      to_delivery = create(:delivery)

      expect {
        BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
      }.not_to change { to_delivery.basket_contents.count }
    end

    specify "do nothing when targer delivery has already a contents" do
      from_delivery = create(:delivery)
      to_delivery = create(:delivery)

      create(:basket_content,
        delivery: from_delivery,
        basket_size_ids_percentages: {
          1001 => 40,
          1002 => 60
        },
        quantity: 100,
        unit: "kg",
        unit_price: 1)
      create(:basket_content,
        delivery: to_delivery,
        basket_size_ids_quantities: {
          1001 => 75,
          1002 => 75
        },
        quantity: 150,
        unit: "pc")

      expect {
        BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
      }.not_to change { to_delivery.basket_contents.count }
    end
  end
end

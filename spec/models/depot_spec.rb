require "rails_helper"

describe Depot do
  def member_ordered_names
    Depot.member_ordered.map(&:name)
  end

  specify "#member_ordered" do
    farm = create(:depot, price: 0, name: "ferme")
    create(:depot, price: 2, name: "poste")
    create(:depot, price: 1, name: "gare", public_name: "")

    expect(member_ordered_names).to eq %w[ferme gare poste]

    Current.acp.update! depots_member_order_mode: "price_desc"
    expect(member_ordered_names).to eq %w[poste gare ferme]

    Current.acp.update! depots_member_order_mode: "name_asc"
    expect(member_ordered_names).to eq %w[ferme gare poste]

    farm.update! member_order_priority: 2
    expect(member_ordered_names).to eq %w[gare poste ferme]
  end

  describe "#deliveries_count" do
    it "counts future deliveries when exits" do
      create_deliveries(2)
      depot = create(:depot)

      expect { create(:delivery, date: 1.year.from_now) }
        .to change { depot.reload.billable_deliveries_counts }.from([ 2 ]).to([ 1 ])
    end
  end

  describe "#move_to" do
    it "moves depot to a new position" do
      depot1 = create(:depot, id: 1)
      depot2 = create(:depot, id: 2)
      depot3 = create(:depot, id: 3)
      create(:membership, depot: depot1)
      create(:membership, depot: depot2)
      create(:membership, depot: depot3)

      expect { depot1.move_to(2, Delivery.first) }
        .to change { Depot.pluck(:id) }
        .from([ 1, 2, 3 ])
        .to([ 2, 1, 3 ])
    end

    it "moves depot to a new position with delivery context respected" do
      depot1 = create(:depot, id: 1)
      create(:depot, id: 2)
      depot3 = create(:depot, id: 3)
      create(:membership, depot: depot1)
      create(:membership, depot: depot3)

      expect { depot1.move_to(2, Delivery.first) }
        .to change { Depot.pluck(:id) }
        .from([ 1, 2, 3 ])
        .to([ 2, 3, 1 ])
    end
  end

  describe "#move_member_to" do
    def depot_member_names(depot, delivery)
      depot.baskets_for(delivery).map(&:member).map(&:name)
    end

    let(:depot) { create(:depot, delivery_sheets_mode: "home_delivery") }
    let(:alice) { create(:member, name: "Alice") }
    let(:bob) { create(:member, name: "Bob") }
    let(:charlie) { create(:member, name: "Charlie") }

    it "moves member to a new position" do
      create(:membership, depot: depot, member: alice)
      create(:membership, depot: depot, member: bob)
      create(:membership, depot: depot, member: charlie)

      expect { depot.move_member_to(2, alice, Delivery.first) }
        .to change { depot_member_names(depot, Delivery.first) }
        .from(%w[Alice Bob Charlie])
        .to(%w[Bob Alice Charlie])
    end

    it "moves member to a new position with delivery context respected", freeze: "2023-01-01" do
      delivery1 = create(:delivery, date: "2023-01-05")
      delivery2 = create(:delivery, date: "2023-02-01")
      create(:membership, depot: depot, member: alice, ended_on: "2023-01-31")
      create(:membership, depot: depot, member: bob)
      create(:membership, depot: depot, member: charlie)

      expect { depot.move_member_to(1, charlie, delivery2) }
        .to change { depot_member_names(depot, delivery2) }
        .from(%w[Bob Charlie])
        .to(%w[Charlie Bob])

      # Alice has not been sorted explicitly, so it's sorted by name at the end
      expect(depot_member_names(depot, delivery1)).to eq %w[Charlie Bob Alice]
    end

    specify "signature sheets mode is always ordered by name" do
      create(:membership, depot: depot, member: alice)
      create(:membership, depot: depot, member: bob)
      create(:membership, depot: depot, member: charlie)

      depot.move_member_to(2, alice, Delivery.first)

      expect(depot_member_names(depot, Delivery.first)).to eq %w[Bob Alice Charlie]

      depot.update! delivery_sheets_mode: "signature"

      expect(depot_member_names(depot, Delivery.first)).to eq %w[Alice Bob Charlie]
    end
  end
end

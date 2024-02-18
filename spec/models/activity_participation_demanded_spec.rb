require "rails_helper"

describe ActivityParticipationDemanded, freeze: "2022-01-01" do
  def demanded_for(membership)
    described_class.new(
      membership,
      Current.acp.activity_participations_demanded_logic
    ).count
  end

  context "default logic" do
    specify "salary basket" do
      member = create(:member, :active, salary_basket: true)

      expect(demanded_for(member.membership)).to eq 0
    end

    specify "all deliveries baskets" do
      create_deliveries(3)
      membership = create(:membership, activity_participations_demanded_annually: 2)

      expect(demanded_for(membership)).to eq 2 # (3/3.0×2).round
    end

    specify "1/2 of the baskets" do
      create(:delivery, date: "2022-01-01")
      create(:delivery, date: "2022-02-01")
      create(:delivery, date: "2022-03-01")
      create(:delivery, date: "2022-04-01")
      membership = create(:membership,
        started_on: "2022-01-01",
        ended_on: "2022-02-01",
        activity_participations_demanded_annually: 2)

      expect(demanded_for(membership)).to eq 1 # (2/4.0×2).round
    end

    specify "1/5 of the baskets" do
      create(:delivery, date: "2022-01-01")
      create(:delivery, date: "2022-02-01")
      create(:delivery, date: "2022-03-01")
      create(:delivery, date: "2022-04-01")
      create(:delivery, date: "2022-05-01")
      membership = create(:membership,
        started_on: "2022-01-01",
        ended_on: "2022-01-31",
        activity_participations_demanded_annually: 2)

      expect(demanded_for(membership)).to eq 0 # (1/5.0×2).round
    end

    specify "2/1 of the baskets" do
      create(:basket_size)
      create(:delivery, date: "2022-01-01")
      create(:delivery, date: "2022-02-01")
      create(:delivery, date: "2022-03-01")
      create(:delivery, date: "2022-04-01")
      depot = create(:depot)
      all_cycle = create(:delivery_cycle, depots: [ depot ])
      cycle = create(:delivery_cycle, results: :odd, depots: [ depot ])
      membership = create(:membership,
        started_on: "2022-01-01",
        ended_on: "2022-05-01",
        depot: depot,
        activity_participations_demanded_annually: 2)
      membership.update!(
        new_config_from: "2022-05-01",
        delivery_cycle: cycle)

      expect(demanded_for(membership)).to eq 2 # (4/[2,4].max×2).round
    end
  end

  context "custom logic" do
    before do
      Current.acp.update!(activity_participations_demanded_logic: <<~LIQUID)
        {% if member.salary_basket %}
          0
        {% elsif membership.baskets < 2 %}
          0
        {% elsif membership.baskets == 2 %}
          {{ membership.full_year_activity_participations | divided_by: 2 | round }}
        {% else %}
          {{ membership.full_year_activity_participations }}
        {% endif %}
      LIQUID
    end

    specify "salary basket" do
      member = create(:member, :active, salary_basket: true)

      expect(demanded_for(member.membership)).to eq 0
    end

    specify "1 basket" do
      create_deliveries(1)
      membership = create(:membership, activity_participations_demanded_annually: 2)

      expect(demanded_for(membership)).to eq 0
    end

    specify "2 baskets" do
      create_deliveries(2)
      membership = create(:membership, activity_participations_demanded_annually: 2)

      expect(demanded_for(membership)).to eq 1
    end

    specify "3 baskets" do
      create_deliveries(3)
      membership = create(:membership, activity_participations_demanded_annually: 2)

      expect(demanded_for(membership)).to eq 2
    end
  end
end

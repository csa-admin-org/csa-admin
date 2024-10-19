# frozen_string_literal: true

require "rails_helper"

describe Tenant do
  specify ".inside? / .outside?" do
    expect(Tenant.current).to eq "test"
    expect(Tenant).to be_inside
    expect(Tenant).not_to be_outside

    Tenant.reset
    expect(Tenant.current).to eq Tenant.default
    expect(Tenant).not_to be_inside
    expect(Tenant).to be_outside
  end

  specify ".switch!" do
    Tenant.reset

    expect(Tenant.current).to eq Tenant.default
    Tenant.switch!("test")
    expect(Tenant.current).to eq "test"
  end

  specify ".switch! from inside?" do
    expect {
      Tenant.switch!("other")
    }.to raise_error("Illegal tenant switch (test => other)")
  end

  specify "creates default deliveries cycle" do
    Tenant.reset
    Tenant.create!("another_test") do
      create(:organization, :another)
    end

    Tenant.switch!("another_test") do
      expect(DeliveryCycle.count).to eq 1
      expect(DeliveryCycle.first).to have_attributes(
        names: {
          "de" => "Alle",
          "fr" => "Toutes",
          "it" => "Tutte",
          "en" => "All"
        })
    end
  end
end

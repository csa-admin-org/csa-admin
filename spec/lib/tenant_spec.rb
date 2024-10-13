# frozen_string_literal: true

require "rails_helper"

describe Tenant do
  specify ".inside? / .outside?" do
    expect(Tenant.current).to eq "ragedevert"
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
    Tenant.switch!("ragedevert")
    expect(Tenant.current).to eq "ragedevert"
  end

  specify ".switch! from inside?" do
    expect {
      Tenant.switch!("other-org")
    }.to raise_error("Illegal tenant switch (ragedevert => other-org)")
  end
end

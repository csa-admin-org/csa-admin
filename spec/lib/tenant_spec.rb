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

  specify ".switch" do
    Tenant.reset

    expect(Tenant.current).to eq Tenant.default
    expect(Tenant.current).not_to eq "ragedevert"
    Tenant.switch("ragedevert") do
      expect(Tenant.current).to eq "ragedevert"
    end
    expect(Tenant.current).to eq Tenant.default
  end
end

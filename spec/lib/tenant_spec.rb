# frozen_string_literal: true

require "rails_helper"

describe Tenant do
  specify ".find_by host" do
    expect(Tenant.find_by(host: "admin.acme.test")).to eq "acme"
    expect(Tenant.find_by(host: "foo.acme.test")).to eq "acme"
    expect(Tenant.find_by(host: "admin.unknown.test")).to be nil
  end

  specify ".domain" do
    expect(Tenant.current).to eq "acme"
    expect(Tenant.domain).to eq "acme.test"
  end

  specify ".inside? / .outside?" do
    expect(Tenant.current).to eq "acme"
    expect(Tenant).to be_inside
    expect(Tenant).not_to be_outside
  end

  specify ".exists?" do
    expect(Tenant.exists?("acme")).to be true
    expect(Tenant.exists?("unknown")).to be false
  end

  specify ".connect to unknown tenant" do
    expect(Tenant.current).to eq "acme"
    expect {
      Tenant.switch("unknown") { }
    }.to raise_error("Unknown tenant 'unknown'")
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Organization do
  specify "validate url https" do
    org = Organization.new(url: "http://www.ragedevert.ch")
    expect(org).not_to have_valid(:url)

    org = Organization.new(url: "https://www.ragedevert.ch")
    expect(org).to have_valid(:url)
  end

  specify "validates email_default_from format" do
    org = Organization.new(email_default_host: "https://membres.ragedevert.ch")

    expect(org.email_hostname).to eq "ragedevert.ch"

    org.email_default_from = "info@ragedevert.ch"
    expect(org).to have_valid(:email_default_from)

    org.email_default_from = "contact@ragedevert.ch"
    expect(org).to have_valid(:email_default_from)

    org.email_default_from = "info@rave.ch"
    expect(org).not_to have_valid(:email_default_from)

    org.email_default_from = "ragedevert.ch"
    expect(org).not_to have_valid(:email_default_from)
  end

  specify "validates that activity_price cannot be 0" do
    org = Organization.new(activity_price: nil)
    expect(org).not_to have_valid(:activity_price)
  end

  specify "validates activity_participations_demanded_logic liquid syntax" do
    org = Organization.new(activity_participations_demanded_logic: <<~LIQUID)
      {% if member.salary_basket %}
    LIQUID

    expect(org).not_to have_valid(:activity_participations_demanded_logic)
    expect(org.errors[:activity_participations_demanded_logic])
      .to include("Liquid syntax error: 'if' tag was never closed")
  end

  specify "validates basket_price_extra_dynamic_pricing liquid syntax" do
    org = Organization.new(basket_price_extra_dynamic_pricing: <<~LIQUID)
      {% if extra %}
    LIQUID

    expect(org).not_to have_valid(:basket_price_extra_dynamic_pricing)
    expect(org.errors[:basket_price_extra_dynamic_pricing])
      .to include("Liquid syntax error: 'if' tag was never closed")
  end

  specify "validate share related attribute presence" do
    org = Organization.new(share_price: 50, shares_number: nil)
    expect(org).not_to have_valid(:shares_number)

    org = Organization.new(share_price: nil, shares_number: 1)
    expect(org).not_to have_valid(:share_price)

    org = Organization.new(share_price: 50, shares_number: 1)
    expect(org).to have_valid(:share_price)
    expect(org).to have_valid(:shares_number)
  end

  describe "validates IBAN format" do
    specify "with CH QR IBAN" do
      org = Organization.new(country_code: "CH")

      org.iban = "CH3230114A012B456789z"
      expect(org).to have_valid(:iban)
      expect(org.iban).to eq "CH3230114A012B456789Z"
      expect(org.iban_formatted).to eq "CH32 3011 4A01 2B45 6789 Z"

      org.iban = "CH3231114A012B456789z"
      expect(org).to have_valid(:iban)

      org.iban = "CH3232004A012B456789z"
      expect(org).not_to have_valid(:iban)

      org.iban = "CH 33 30767 000K 5510"
      expect(org).not_to have_valid(:iban)

      org.iban = ""
      expect(org).not_to have_valid(:iban)
    end

    specify "with FR IBAN" do
      org = Organization.new(country_code: "FR")

      org.iban = "FR7630006000011234567890189"
      expect(org).to have_valid(:iban)
      expect(org.iban).to eq "FR7630006000011234567890189"
      expect(org.iban_formatted).to eq "FR76 3000 6000 0112 3456 7890 189"

      org.iban = "FR763000600001123456789018"
      expect(org).not_to have_valid(:iban)

      org.iban = "DE89370400440532013000"
      expect(org).not_to have_valid(:iban)
    end

    specify "with DE IBAN" do
      org = Organization.new(country_code: "DE")

      org.iban = "DE89370400440532013000"
      expect(org).to have_valid(:iban)
      expect(org.iban).to eq "DE89370400440532013000"
      expect(org.iban_formatted).to eq "DE89 3704 0044 0532 0130 00"

      org.iban = "DE8937040044053201300"
      expect(org).not_to have_valid(:iban)

      org.iban = "FR7630006000011234567890189"
      expect(org).not_to have_valid(:iban)
    end
  end

  describe "#billing_year_divisions=" do
    it "keeps only allowed divisions" do
      org = Organization.new(billing_year_divisions: [ "", "1", "6", "12" ])
      expect(org.billing_year_divisions).to eq [ 1, 12 ]
    end
  end

  describe "url=" do
    it "sets host at the same time" do
      org = Organization.new(url: "https://www.ragedevert.ch")
      expect(org.host).to eq "ragedevert"
    end
  end

  specify "creates default deliveries cycle" do
    Tenant.reset
    create(:organization, tenant_name: "test")
    Tenant.switch!("test")

    expect(DeliveryCycle.count).to eq 1
    expect(DeliveryCycle.first).to have_attributes(
      names: {
        "de" => "Alle",
        "fr" => "Toutes",
        "it" => "Tutte",
        "en" => "All"
      })
  end

  specify "apply_annual_fee_change" do
    current_org.update!(annual_fee: 30)

    create(:member, annual_fee: 20)
    create(:member, annual_fee: 30)
    create(:member, annual_fee: 30)

    expect { current_org.update!(annual_fee: 40) }
      .to change { Member.where(annual_fee: 40).count }.by(2)

    expect(Member.pluck(:annual_fee)).to contain_exactly(20, 40, 40)
  end
end

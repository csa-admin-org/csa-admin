require "rails_helper"

describe ACP do
  specify "validate url https" do
    acp = ACP.new(url: "http://www.ragedevert.ch")
    expect(acp).not_to have_valid(:url)

    acp = ACP.new(url: "https://www.ragedevert.ch")
    expect(acp).to have_valid(:url)
  end

  specify "validates email_default_from format" do
    acp = ACP.new(email_default_host: "https://membres.ragedevert.ch")

    expect(acp.email_hostname).to eq "ragedevert.ch"

    acp.email_default_from = "info@ragedevert.ch"
    expect(acp).to have_valid(:email_default_from)

    acp.email_default_from = "contact@ragedevert.ch"
    expect(acp).to have_valid(:email_default_from)

    acp.email_default_from = "info@rave.ch"
    expect(acp).not_to have_valid(:email_default_from)

    acp.email_default_from = "ragedevert.ch"
    expect(acp).not_to have_valid(:email_default_from)
  end

  specify "validates that activity_price cannot be 0" do
    acp = ACP.new(activity_price: nil)
    expect(acp).not_to have_valid(:activity_price)
  end

  specify "validates activity_participations_demanded_logic liquid syntax" do
    acp = ACP.new(activity_participations_demanded_logic: <<~LIQUID)
      {% if member.salary_basket %}
    LIQUID

    expect(acp).not_to have_valid(:activity_participations_demanded_logic)
    expect(acp.errors[:activity_participations_demanded_logic])
      .to include("Liquid syntax error: 'if' tag was never closed")
  end

  specify "validates basket_price_extra_dynamic_pricing liquid syntax" do
    acp = ACP.new(basket_price_extra_dynamic_pricing: <<~LIQUID)
      {% if extra %}
    LIQUID

    expect(acp).not_to have_valid(:basket_price_extra_dynamic_pricing)
    expect(acp.errors[:basket_price_extra_dynamic_pricing])
      .to include("Liquid syntax error: 'if' tag was never closed")
  end

  specify "validate share related attribute presence" do
    acp = ACP.new(share_price: 50, shares_number: nil)
    expect(acp).not_to have_valid(:shares_number)

    acp = ACP.new(share_price: nil, shares_number: 1)
    expect(acp).not_to have_valid(:share_price)

    acp = ACP.new(share_price: 50, shares_number: 1)
    expect(acp).to have_valid(:share_price)
    expect(acp).to have_valid(:shares_number)
  end

  describe "validates IBAN format" do
    specify "with CH QR IBAN" do
      acp = ACP.new(country_code: "CH")

      acp.iban = "CH3230114A012B456789z"
      expect(acp).to have_valid(:iban)
      expect(acp.iban).to eq "CH3230114A012B456789Z"
      expect(acp.iban_formatted).to eq "CH32 3011 4A01 2B45 6789 Z"

      acp.iban = "CH3231114A012B456789z"
      expect(acp).to have_valid(:iban)

      acp.iban = "CH3232004A012B456789z"
      expect(acp).not_to have_valid(:iban)

      acp.iban = "CH 33 30767 000K 5510"
      expect(acp).not_to have_valid(:iban)

      acp.iban = ""
      expect(acp).not_to have_valid(:iban)
    end

    specify "with FR IBAN" do
      acp = ACP.new(country_code: "FR")

      acp.iban = "FR7630006000011234567890189"
      expect(acp).to have_valid(:iban)
      expect(acp.iban).to eq "FR7630006000011234567890189"
      expect(acp.iban_formatted).to eq "FR76 3000 6000 0112 3456 7890 189"

      acp.iban = "FR763000600001123456789018"
      expect(acp).not_to have_valid(:iban)

      acp.iban = "DE89370400440532013000"
      expect(acp).not_to have_valid(:iban)
    end

    specify "with DE IBAN" do
      acp = ACP.new(country_code: "DE")

      acp.iban = "DE89370400440532013000"
      expect(acp).to have_valid(:iban)
      expect(acp.iban).to eq "DE89370400440532013000"
      expect(acp.iban_formatted).to eq "DE89 3704 0044 0532 0130 00"

      acp.iban = "DE8937040044053201300"
      expect(acp).not_to have_valid(:iban)

      acp.iban = "FR7630006000011234567890189"
      expect(acp).not_to have_valid(:iban)
    end
  end

  describe "#billing_year_divisions=" do
    it "keeps only allowed divisions" do
      acp = ACP.new(billing_year_divisions: [ "", "1", "6", "12" ])
      expect(acp.billing_year_divisions).to eq [ 1, 12 ]
    end
  end

  describe "url=" do
    it "sets host at the same time" do
      acp = ACP.new(url: "https://www.ragedevert.ch")
      expect(acp.host).to eq "ragedevert"
    end
  end

  specify "creates default deliveries cycle" do
    Tenant.reset
    create(:acp, tenant_name: "test")
    Tenant.switch!("test")

    expect(DeliveryCycle.count).to eq 1
    expect(DeliveryCycle.first).to have_attributes(
      names: {
        "de" => "Alle",
        "fr" => "Toutes",
        "it" => "Tutte"
      })
  end

  specify "apply_annual_fee_change" do
    current_acp.update!(annual_fee: 30)

    create(:member, annual_fee: 20)
    create(:member, annual_fee: 30)
    create(:member, annual_fee: 30)

    expect { current_acp.update!(annual_fee: 40) }
      .to change { Member.where(annual_fee: 40).count }.by(2)

    expect(Member.pluck(:annual_fee)).to contain_exactly(20, 40, 40)
  end
end

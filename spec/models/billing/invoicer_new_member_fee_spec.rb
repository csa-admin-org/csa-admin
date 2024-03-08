require "rails_helper"

describe Billing::InvoicerNewMemberFee do
  before do
    current_acp.update!(
      features: [ "new_member_fee" ],
      new_member_fee_description: "Paniers vides",
      trial_basket_count: 3,
      new_member_fee: 30)
  end

  def invoice(member, **attrs)
    described_class.invoice(member, **attrs)
  end

  specify "create invoice for recent new member", freeze: "2023-02-01" do
    member = create(:member, :waiting)
    create(:membership, member: member, deliveries_count: 4)

    expect { invoice(member) }.to change { member.invoices.count }.by(1)

    invoice = member.invoices.last
    expect(invoice).to have_attributes(
      date: Date.current,
      entity_type: "NewMemberFee",
      amount: 30)
    expect(invoice.items.count).to eq 1
    expect(invoice.items.first).to have_attributes(
      description: "Paniers vides",
      amount: 30)
  end

  specify "do nothing if new_member_fee is not enabled", freeze: "2023-02-01" do
    current_acp.update!(features: [])
    member = create(:member, :waiting)
    create(:membership, member: member, deliveries_count: 4)

    expect { invoice(member) }.not_to change { member.invoices.count }
  end

  specify "do nothing if member is not active" do
    member = create(:member, :waiting)

    expect { invoice(member) }.not_to change { member.invoices.count }
  end

  specify "do nothing if member already has a new_member_fee invoice", freeze: "2023-02-01" do
    member = create(:member, :waiting)
    create(:membership, member: member, deliveries_count: 4)

    expect { invoice(member) }.to change { member.invoices.count }.by(1)
    expect { invoice(member) }.to change { member.invoices.count }.by(0)
  end

  specify "do nothing if member is still on trial basket", freeze: "2023-01-16" do
    member = create(:member, :waiting)
    create(:membership, member: member, deliveries_count: 4)

    expect(member.baskets.trial.last.delivery.date.to_s).to eq "2023-01-17"
    expect(member.baskets.normal.first.delivery.date.to_s).to eq "2023-01-24"
    expect { invoice(member) }.to change { member.invoices.count }.by(0)
  end

  specify "do nothing if member first non-trial basket is no more recent", freeze: "2023-02-15" do
    member = create(:member, :waiting)
    create(:membership, member: member, deliveries_count: 4)

    expect(member.baskets.normal.first.delivery.date.to_s).to eq "2023-01-24"
    expect { invoice(member) }.to change { member.invoices.count }.by(0)
  end

  specify "ignore member not billable (SEPA)" do
    Current.acp.update!(country_code: "DE", iban: "DE89370400440532013000")
    member = create(:member, :waiting, iban: nil)
    create(:membership, member: member, deliveries_count: 4)

    expect { invoice(member) }.not_to change { member.invoices.count }
  end
end

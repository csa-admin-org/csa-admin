require "rails_helper"

describe Billing::InvoicerACPShare do
  before { current_acp.update!(share_price: 250, shares_number: 1, trial_basket_count: 0) }

  def invoice(member, **attrs)
    described_class.invoice(member, **attrs)
  end

  it "creates invoice for member with ongoing memberships that does not have ACP shares billed already", freeze: "2023-01-01" do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member

    expect { invoice(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(0).to(3)
    invoice = member.invoices.last
    expect(invoice.entity_type).to eq "ACPShare"
    expect(invoice.acp_shares_number).to eq 3
    expect(invoice.date).to eq Date.current
  end

  it "sends emails directly when the send_email attribute is set", freeze: "2023-01-01", sidekiq: :inline do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    invoice = nil

    expect {
      invoice = invoice(member, send_email: true)
    }.to change { InvoiceMailer.deliveries.size }.by(1)

    mail = InvoiceMailer.deliveries.last
    expect(mail.subject).to eq "Nouvelle facture ##{invoice.id}"
  end

  it "creates invoice when ACP shares already partially billed", freeze: "2023-01-01" do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    create(:invoice, member: member, acp_shares_number: 2)

    expect { invoice(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(2).to(3)
  end

  it "creates invoice when ACP shares desired and on support", freeze: "2023-01-01" do
    member = create(:member, state: "support", desired_acp_shares_number: 2)

    expect { invoice(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(0).to(2)
  end

  it "does nothing when ACP shares already billed", freeze: "2023-01-01" do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    create(:invoice, member: member, acp_shares_number: 3)

    expect { invoice(member) }.not_to change { member.invoices.count }
  end

  it "does nothing when ACP shares already exists prior to system use", freeze: "2023-01-01" do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    member.update!(existing_acp_shares_number: 3)

    expect { invoice(member) }.not_to change { member.invoices.count }
  end

  it "does nothing when inactive" do
    member = create(:member, :inactive)
    expect { invoice(member) }.not_to change { member.invoices.count }
  end

  specify "ignore member in trial period" do
    basket_size = create(:basket_size, acp_shares_number: 3)
    Current.acp.update!(trial_basket_count: 3)
    membership = travel_to "2021-01-01" do
      create(:delivery, date: "2021-09-21")
      create(:delivery, date: "2021-09-28")
      create(:delivery, date: "2021-10-05")
      create(:membership, basket_size: basket_size, started_on: "2021-09-20")
    end
    member = membership.member

    travel_to "2021-03-01" do
      membership.update_baskets_counts!
      member.reload
      expect { invoice(member) }.not_to change { member.invoices.count }
    end
    travel_to "2021-09-29" do
      membership.update_baskets_counts!
      member.reload
      expect { invoice(member) }.not_to change { member.invoices.count }
    end
    travel_to "2021-10-05" do
      membership.update_baskets_counts!
      member.reload
      expect { invoice(member) }.not_to change { member.invoices.count }
    end
    travel_to "2021-10-06" do
      membership.update_baskets_counts!
      member.reload
      expect { invoice(member) }.to change { member.invoices.count }.by(1)
    end
  end
end

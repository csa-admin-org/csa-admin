require 'rails_helper'

describe Billing::InvoicerACPShare, freeze: '2022-01-01' do
  before { current_acp.update!(share_price: 250, trial_basket_count: 0) }

  def invoice(member, **attrs)
    described_class.invoice(member, **attrs)
  end

  it 'creates invoice for member with ongoing memberships that does not have ACP shares billed already' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member

    expect { invoice(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(0).to(3)
    invoice = member.invoices.last
    expect(invoice.object_type).to eq 'ACPShare'
    expect(invoice.acp_shares_number).to eq 3
    expect(invoice.date).to eq Date.current
  end

  it 'sends emails directly when the send_email attribute is set' do
    MailTemplate.create!(title: :invoice_created)
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

  it 'creates invoice when ACP shares already partially billed' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    create(:invoice, member: member, acp_shares_number: 2)

    expect { invoice(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(2).to(3)
  end

  it 'creates invoice when ACP shares desired and on support ' do
    member = create(:member, state: 'support', desired_acp_shares_number: 2)

    expect { invoice(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(0).to(2)
  end

  it 'does nothing when ACP shares already billed' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    create(:invoice, member: member, acp_shares_number: 3)

    expect { invoice(member) }.not_to change { member.invoices.count }
  end

  it 'does nothing when ACP shares already exists prior to system use' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    member.update!(existing_acp_shares_number: 3)

    expect { invoice(member) }.not_to change { member.invoices.count }
  end

  it 'does nothing when inactive' do
    member = create(:member, :inactive)
    expect { invoice(member) }.not_to change { member.invoices.count }
  end
end

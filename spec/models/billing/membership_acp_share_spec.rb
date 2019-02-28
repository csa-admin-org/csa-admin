require 'rails_helper'

describe Billing::MembershipACPShare do
  before { current_acp.update!(share_price: 250) }

  def invoice!(member, **attrs)
    Billing::MembershipACPShare.invoice!(member, attrs)
  end

  it 'creates invoice for member with ongoing memberships that does not have ACP shares billed already', freeze: '01-06-2018' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member

    expect { invoice!(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(0).to(3)
    invoice = member.invoices.last
    expect(invoice.object_type).to eq 'ACPShare'
    expect(invoice.acp_shares_number).to eq 3
    expect(invoice.date).to eq Date.current
  end

  it 'sends emails directly when the send_email attribute is set', freeze: '01-06-2018' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member

    invoice!(member, send_email: true)

    expect(email_adapter.deliveries.first).to match(hash_including(
      to: member.emails,
      template: 'invoice-new-fr',
      template_data: hash_including(invoice_amount: 'CHF 750.00')
    ))
  end

  it 'creates invoice when ACP shares already partially billed', freeze: '01-06-2018' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    create(:invoice, member: member, acp_shares_number: 2)

    expect { invoice!(member) }
      .to change { member.invoices.count }.by(1)
      .and change { member.acp_shares_number }.from(2).to(3)
  end

  it 'does nothing when ACP shares already billed' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    create(:invoice, member: member, acp_shares_number: 3)

    expect { invoice!(member) }.not_to change { member.invoices.count }
  end

  it 'does nothing when ACP shares already exists prior to system use' do
    basket_size = create(:basket_size, acp_shares_number: 3)
    membership = create(:membership, basket_size: basket_size)
    member = membership.member
    member.update!(existing_acp_shares_number: 3)

    expect { invoice!(member) }.not_to change { member.invoices.count }
  end

  it 'does nothing when no membership' do
    member = create(:member, :inactive)
    expect { invoice!(member) }.not_to change { member.invoices.count }
  end
end

require 'rails_helper'

describe Billing::MissingActivityParticipationsInvoicerJob do
  before { Current.acp.update!(activity_price: 90) }

  specify 'noop if no activty price' do
    Current.acp.update!(activity_price: 0)

    membership = create(:membership, activity_participations_demanded_annualy: 2)

    expect { described_class.perform_later(membership) }
      .not_to change(Invoice, :count)
  end

  specify 'noop if no missing activity participations' do
    membership = create(:membership, activity_participations_demanded_annualy: 0)

    expect { described_class.perform_later(membership) }
      .not_to change(Invoice, :count)
  end

  specify 'create invoice and send invoice' do
    membership = create(:membership, activity_participations_demanded_annualy: 2)

    expect { described_class.perform_later(membership) }
      .to change(Invoice, :count).by(1)
      .and change { membership.reload.missing_activity_participations }.to(0)
      .and change { InvoiceMailer.deliveries.size }.by(1)

    invoice = Invoice.last
    expect(invoice).to have_attributes(
      member_id: membership.member_id,
      date: Date.today,
      paid_missing_activity_participations: 2,
      entity_type: 'ActivityParticipation',
      entity_id: nil,
      amount: 2 * 90)
    expect(invoice).to be_sent
  end

  specify 'create invoice for previous year membership' do
    Current.acp.update!(fiscal_year_start_month: 5)
    membership = travel_to '2021-01-06' do
      create(:membership, activity_participations_demanded_annualy: 2)
    end

    expect { described_class.perform_later(membership) }
      .to change(Invoice, :count).by(1)

    invoice = Invoice.last
    expect(invoice.date.to_s).to eq '2021-04-30'
    expect(invoice).to be_sent
  end
end

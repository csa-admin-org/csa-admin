require 'rails_helper'

describe InvoiceOverdueNoticer do
  let(:invoice) { create(:invoice, :support, :open, sent_at: 40.days.ago) }

  def perform(invoice)
    InvoiceOverdueNoticer.perform(invoice)
  end

  it 'increments invoice overdue_notices_count' do
    expect { perform(invoice) }.to change(invoice, :overdue_notices_count).by(1)
  end

  it 'sets invoice overdue_notices_sent_at' do
    expect { perform(invoice) }
      .to change(invoice, :overdue_notice_sent_at).from(nil)
  end

  it 'sends invoice overdue_notice email' do
    expect { perform(invoice) }
      .to change { ActionMailer::Base.deliveries.count }.by(1)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to include('Rappel')
  end

  specify 'only send overdue notice when invoice is open' do
    invoice = create(:invoice, :support, :open)
    create(:payment, invoice: invoice, amount: Member::SUPPORT_PRICE)
    expect(invoice.reload.state).to eq 'closed'
    expect { perform(invoice) }
      .to change { ActionMailer::Base.deliveries.count }.by(0)
  end

  specify 'only send first overdue notice after 35 days' do
    invoice = create(:invoice, :support, sent_at: 10.days.ago)
    expect { perform(invoice) }
      .to change { ActionMailer::Base.deliveries.count }.by(0)
  end

  specify 'only send second overdue notice after 35 days first one' do
    invoice = create(:invoice, :support, :open,
      overdue_notices_count: 1,
      overdue_notice_sent_at: 10.days.ago
    )
    expect { perform(invoice) }
      .to change { ActionMailer::Base.deliveries.count }.by(0)
  end

  it 'sends second overdue notice after 35 days first one' do
    invoice = create(:invoice, :support, :open,
      overdue_notices_count: 1,
      overdue_notice_sent_at: 40.days.ago
    )
    expect { perform(invoice) }
      .to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(invoice.overdue_notices_count).to eq 2
  end
end

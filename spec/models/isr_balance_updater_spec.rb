require 'rails_helper'

describe IsrBalanceUpdater do
  let(:raiffeisen) { double(Raiffeisen, get_isr_data: data) }
  let(:data) do
    [
      { invoice_id: 2, amount: 1.15, data: 'foo'  },
      { invoice_id: 2, amount: 0.95, data: 'foo' }
    ]
  end
  before { allow(Raiffeisen).to receive(:new) { raiffeisen } }

  def update_all
    IsrBalanceUpdater.new.update_all
  end

  it 'updates invoice isr balance data' do
    invoice = create(:invoice, :support, id: 2)
    expect { update_all }.to change { invoice.reload.isr_balance_data }
    expect(invoice.isr_balance_data).to eq(
      '0-foo' => 1.15,
      '1-foo' => 0.95
    )
  end
end

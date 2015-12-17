require 'rails_helper'

describe IsrBalanceUpdater do
  let(:raiffeisen) { double(Raiffeisen, get_isr_data: data) }
  let(:data) do
    [
      { invoice_id: 2, amount: 1.15, data: 'foo'  },
      { invoice_id: 2, amount: 0.95, data: 'bar' },
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
      'foo' => { 'amount' => 1.15, 'date' => Time.zone.today.to_s },
      'bar' => { 'amount' => 0.95, 'date' => Time.zone.today.to_s }
    )
  end

  it 'updates invoice new isr balance data' do
    invoice = create(:invoice, :support,
      id: 2,
      isr_balance_data: {
        'foo' => { 'amount' => 1.15, 'date' => Time.zone.today.to_s }
      }
    )
    expect { update_all }.to change { invoice.reload.isr_balance_data }
    expect(invoice.isr_balance_data).to eq(
      'foo' => { 'amount' => 1.15, 'date' => Time.zone.today.to_s },
      'bar' => { 'amount' => 0.95, 'date' => Time.zone.today.to_s }
    )
  end

  it 'does not change invoice isr balance data if no change' do
    invoice = create(:invoice, :support,
      id: 2,
      isr_balance_data: {
        'foo' => { 'amount' => 1.15, 'date' => Time.zone.today.to_s },
        'bar' => { 'amount' => 0.95, 'date' => Time.zone.today.to_s }
      }
    )
    expect { update_all }.not_to change { invoice.reload.isr_balance_data }
  end
end

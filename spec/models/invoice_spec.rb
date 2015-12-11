require 'rails_helper'

describe Invoice do
  it 'raises on amount=' do
    expect { build(:invoice, amount: 1).to raise_error }
  end

  it 'raises on memberships_amount=' do
    expect { build(:invoice, memberships_amount: 1).to raise_error }
  end

  it 'raises on remaining_memberships_amount=' do
    expect { build(:invoice, remaining_memberships_amount: 1).to raise_error }
  end

  it 'validates memberships_amounts_data presence when no support_amount' do
    expect(build(:invoice)).not_to have_valid(:memberships_amounts_data)
  end

  it 'validates memberships_amounts_data keys' do
    expect(build(:invoice, memberships_amounts_data: [foo: 'bar']))
      .not_to have_valid(:memberships_amounts_data)
  end

  it 'validates date uniqueness' do
    invoice = create(:invoice, :membership)
    expect(build(:invoice, :support, member: invoice.member))
      .not_to have_valid(:date)
  end

  describe '#memberships_amounts' do
    let(:invoice) do
      build(:invoice, memberships_amounts_data: [
        { id: 1, description: 'foo', 'amount' => 12 },
        { id: 2, description: 'foo', amount: 34 }
      ])
    end

    specify { expect(invoice.memberships_amounts).to eq 46 }
  end

  context 'when support only' do
    let(:invoice) { create(:invoice, :support) }

    specify { expect(invoice.support_amount).to be_present }
    specify { expect(invoice.memberships_amount).to be_nil }
    specify { expect(invoice.amount).to eq invoice.support_amount }
  end

  context 'when memberships_amounts_data only' do
    let(:invoice) { create(:invoice, :membership) }
    let(:amount) { invoice.member.memberships.first.price }

    specify { expect(invoice.support_amount).to be_nil }
    specify { expect(invoice.memberships_amount).to eq amount  }
    specify { expect(invoice.paid_memberships_amount).to eq 0 }
    specify { expect(invoice.remaining_memberships_amount).to eq amount }
    specify { expect(invoice.amount).to eq invoice.memberships_amount }

    context 'when paid_memberships_amount set' do
      let(:invoice) do
        create(:invoice, :membership, paid_memberships_amount: 99)
      end

      specify { expect(invoice.memberships_amount).to eq amount - 99 }
      specify { expect(invoice.paid_memberships_amount).to eq 99 }
      specify { expect(invoice.remaining_memberships_amount).to eq amount - 99 }
      specify { expect(invoice.amount).to eq invoice.memberships_amount }
    end

    context 'when memberships_amount_fraction set' do
      let(:invoice) do
        create(:invoice, :membership, memberships_amount_fraction: 3)
      end

      specify { expect(invoice.memberships_amount).to eq amount / 3.0 }
      specify { expect(invoice.paid_memberships_amount).to eq 0 }
      specify { expect(invoice.remaining_memberships_amount).to eq amount }
      specify { expect(invoice.amount).to eq invoice.memberships_amount }
    end

    context 'when support present as well' do
      let(:invoice) do
        create(:invoice, :membership, :support)
      end

      specify { expect(invoice.support_amount).to be_present }
      specify do
        expect(invoice.amount)
          .to eq invoice.memberships_amount + invoice.support_amount
      end
    end
  end
end

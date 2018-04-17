require 'rails_helper'

describe Invoice do
  it 'raises on amount=' do
    expect { build(:invoice, :membership, amount: 1) }.to raise_error(NoMethodError)
  end

  it 'raises on balance=' do
    expect { build(:invoice, balance: 1) }.to raise_error(NoMethodError)
  end

  it 'raises on memberships_amount=' do
    expect { build(:invoice, memberships_amount: 1) }
      .to raise_error(NoMethodError)
  end

  it 'raises on remaining_memberships_amount=' do
    expect { build(:invoice, remaining_memberships_amount: 1) }
      .to raise_error(NoMethodError)
  end

  it 'generates and sets pdf after creation' do
    invoice = create(:invoice, :support)
    expect(invoice.pdf_file).to be_attached
    expect(invoice.pdf_file.byte_size).to be_positive
  end

  it 'sends email when send_email is true on creation' do
    expect { create(:invoice, :support) }
      .not_to change { email_adapter.deliveries.size }

    expect { create(:invoice, :support, send_email: true) }
      .to change { email_adapter.deliveries.size }.by(1)
  end

  it 'updates membership recognized_halfday_works' do
    member = create(:member)
    membership = create(:membership, member: member)
    invoice = build(:invoice,
      member: member,
      object_type: 'HalfdayParticipation',
      paid_missing_halfday_works: 2,
      amount: 120)

    expect { invoice.save! }.to change { membership.reload.recognized_halfday_works }.by(2)
    expect { invoice.cancel! }.to change { membership.reload.recognized_halfday_works }.by(-2)
  end

  context 'when support only' do
    let(:invoice) { create(:invoice, :support) }

    specify { expect(invoice.support_amount).to be_present }
    specify { expect(invoice.object_type).to eq 'Support' }
    specify { expect(invoice.memberships_amount).to be_nil }
    specify { expect(invoice.amount).to eq invoice.support_amount }
  end

  context 'when membership' do
    let(:invoice) { create(:invoice, :membership) }
    let(:amount) { invoice.member.memberships.first.price }

    specify { expect(invoice.support_amount).to be_nil }
    specify { expect(invoice.object_type).to eq 'Membership' }
    specify { expect(invoice.memberships_amount).to eq amount  }
    specify { expect(invoice.paid_memberships_amount).to be_zero }
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

    context 'when membership_amount_fraction set' do
      let(:invoice) do
        create(:invoice, :membership, membership_amount_fraction: 3)
      end

      specify { expect(invoice.memberships_amount).to eq amount / 3.0 }
      specify { expect(invoice.paid_memberships_amount).to be_zero }
      specify { expect(invoice.remaining_memberships_amount).to eq amount }
      specify { expect(invoice.amount).to eq invoice.memberships_amount }
    end

    context 'when support present as well' do
      let(:invoice) do
        create(:invoice, :support, :membership)
      end

      specify { expect(invoice.support_amount).to be_present }
      specify do
        expect(invoice.amount)
          .to eq invoice.memberships_amount + invoice.support_amount
      end
    end
  end

  describe '#send!' do
    let(:invoice) { create(:invoice, :support, :not_sent) }

    it 'delivers email' do
      expect { invoice.send! }
        .to change { email_adapter.deliveries.size }.by(1)
      expect(email_adapter.deliveries.first).to match(hash_including(
        template: 'invoice-new-fr'))
    end

    it 'touches sent_at' do
      expect { invoice.send! }.to change(invoice, :sent_at).from(nil)
    end

    it 'sets invoice as open' do
      expect { invoice.send! }.to change(invoice, :state).to('open')
    end

    it 'does nothing when already sent' do
      invoice.touch(:sent_at)
      expect { invoice.send! }
        .not_to change { email_adapter.deliveries.size }
    end

    it 'does nothing when member has no email' do
      invoice.member.update(emails: '')
      expect { invoice.send! }
        .not_to change { email_adapter.deliveries.size }
      expect(invoice.reload.sent_at).to be_nil
    end
  end

  describe '#mark_as_sent!' do
    let(:invoice) { create(:invoice, :support, :not_sent) }

    it 'does not deliver email' do
      expect { invoice.mark_as_sent! }
        .not_to change { email_adapter.deliveries.size }
    end

    it 'touches sent_at' do
      expect { invoice.mark_as_sent! }.to change(invoice, :sent_at).from(nil)
    end

    it 'sets invoice as open' do
      expect { invoice.send! }.to change(invoice, :state).to('open')
    end
  end

  describe 'set_memberships_vat_amount' do
    it 'does not set it for non-membership invoices' do
      invoice = create(:invoice, :support)
      expect(invoice.memberships_vat_amount).to be_nil
    end

    it 'does not set it when ACP as no VAT set' do
      Current.acp.update!(vat_membership_rate: nil)

      invoice = create(:invoice, :membership)
      expect(invoice.memberships_vat_amount).to be_nil
    end

    it 'sets the vat_amount for membership invoice and ACP with rate set' do
      Current.acp.update!(vat_membership_rate: 7.7, vat_number: 'XXX')
      invoice = create(:invoice, :membership)

      expect(invoice.memberships_gross_amount).to eq 1200
      expect(invoice.memberships_net_amount).to eq BigDecimal(1114.21, 6)
      expect(invoice.memberships_vat_amount).to eq BigDecimal(85.79, 4)
    end
  end
end

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
    invoice = create(:invoice, :annual_fee)
    expect(invoice.pdf_file).to be_attached
    expect(invoice.pdf_file.byte_size).to be_positive
  end

  it 'sends email when send_email is true on creation' do
    expect { create(:invoice, :annual_fee) }
      .not_to change { email_adapter.deliveries.size }

    expect { create(:invoice, :annual_fee, send_email: true) }
      .to change { email_adapter.deliveries.size }.by(1)
  end

  it 'closes invoice before sending email' do
    member = create(:member, annual_fee: 42)
    create(:payment, amount: 100, member: member)

    invoice = create(:invoice, :annual_fee, member: member, send_email: true)

    expect(email_adapter.deliveries.last).to match(hash_including(
      template: 'invoice-new-fr',
      template_data: hash_including(invoice_paid: true)
    ))
  end

  it 'updates membership recognized_halfday_works' do
    member = create(:member)
    membership = create(:membership, member: member)
    invoice = build(:invoice,
      member: member,
      paid_missing_halfday_works: 2,
      paid_missing_halfday_works_amount: 120)

    expect { invoice.save! }.to change { membership.reload.recognized_halfday_works }.by(2)
    expect { invoice.cancel! }.to change { membership.reload.recognized_halfday_works }.by(-2)
  end

  context 'when annual fee only' do
    let(:invoice) { create(:invoice, :annual_fee) }

    specify { expect(invoice.annual_fee).to be_present }
    specify { expect(invoice.object_type).to eq 'AnnualFee' }
    specify { expect(invoice.memberships_amount).to be_nil }
    specify { expect(invoice.amount).to eq invoice.annual_fee }
  end

  context 'when membership' do
    let(:invoice) { create(:invoice, :membership) }
    let(:amount) { invoice.member.memberships.first.price }

    specify { expect(invoice.annual_fee).to be_nil }
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

    context 'when annual_fee present as well' do
      let(:invoice) do
        create(:invoice, :annual_fee, :membership)
      end

      specify { expect(invoice.annual_fee).to be_present }
      specify do
        expect(invoice.amount)
          .to eq invoice.memberships_amount + invoice.annual_fee
      end
    end
  end

  context 'when halfday_participation' do
    it 'validates paid_missing_halfday_works_amount presence when paid_missing_halfday_works is present' do
      invoice = build(:invoice, paid_missing_halfday_works: 1)
      expect(invoice).not_to have_valid(:paid_missing_halfday_works_amount)
    end

    it 'sets object_type to HalfdayParticipation with paid_missing_halfday_works' do
      invoice = create(:invoice,
        paid_missing_halfday_works: 1,
        paid_missing_halfday_works_amount: 42)

      expect(invoice.object_type).to eq 'HalfdayParticipation'
      expect(invoice.paid_missing_halfday_works).to eq 1
      expect(invoice.amount).to eq 42
    end
  end

  context 'when acp_share' do
    it 'sets object_type to ACPShare with acp_shares_number' do
      Current.acp.update!(share_price: 250)
      invoice = create(:invoice, acp_shares_number: -2)

      expect(invoice.object_type).to eq 'ACPShare'
      expect(invoice.acp_shares_number).to eq -2
      expect(invoice.amount).to eq -500
    end
  end

  context 'when other' do
    it 'sets items and round to five cents each item' do
      invoice = create(:invoice,
        items_attributes: {
          '0' => { description: 'Un truc cool pas cher', amount: '10.11' },
          '1' => { description: 'Un truc cool pluc cher', amount: '32.33' }
        })

      expect(invoice.object_type).to eq 'Other'
      expect(invoice.items.first.amount).to eq 10.1
      expect(invoice.items.last.amount).to eq 32.35
      expect(invoice.amount).to eq 42.45
    end
  end

  describe '#send!' do
    let(:invoice) { create(:invoice, :annual_fee, :not_sent) }

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
    let(:invoice) { create(:invoice, :annual_fee, :not_sent) }

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
      invoice = create(:invoice, :annual_fee)
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

  describe '#handle_acp_shares_change!' do
    before { Current.acp.update!(share_price: 250) }

    it 'changes inactive member state to support' do
      member = create(:member, :inactive)
      expect { create(:invoice, member: member, acp_shares_number: 1) }
        .to change(member, :state).from('inactive').to('support')
    end

    it 'changes support member state to inactive' do
      member = create(:member, :support_acp_share, acp_shares_number: 1)
      expect { create(:invoice, member: member, acp_shares_number: -1) }
        .to change(member, :state).from('support').to('inactive')
    end
  end
end

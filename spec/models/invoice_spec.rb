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

  context 'with mail template' do
    it 'sends email when send_email is true on creation' do
      expect { create(:invoice, :annual_fee, :unprocessed) }
        .not_to change { InvoiceMailer.deliveries.size }

      expect { create(:invoice, :annual_fee, :unprocessed, send_email: true) }
        .to change { InvoiceMailer.deliveries.size }.by(1)
    end

    specify 'does not send email when invoice is closed' do
      member = create(:member, annual_fee: 42)
      create(:payment, amount: 100, member: member)

      expect {
        create(:invoice, :unprocessed, :annual_fee, member: member, send_email: true)
      }.not_to change { InvoiceMailer.deliveries.size }
    end

    it 'closes invoice before sending email' do
      Current.acp.update!(send_closed_invoice: true)
      member = create(:member, annual_fee: 42)
      create(:payment, amount: 100, member: member)
      invoice = create(:invoice, :unprocessed, :annual_fee, member: member, send_email: true)

      mail = InvoiceMailer.deliveries.last
      expect(mail.subject).to eq "Nouvelle facture ##{invoice.id}"
      expect(mail.html_part.body).to include 'cette facture est considérée comme payée'
    end
  end

  it 'updates membership activity_participations_accepted' do
    member = create(:member)
    membership = create(:membership, member: member)
    invoice = build(:invoice,
      member: member,
      paid_missing_activity_participations: 2,
      activity_price: 60)

    expect { invoice.save! }.to change { membership.reload.activity_participations_accepted }.by(2)
    expect { invoice.reload.cancel! }.to change { membership.reload.activity_participations_accepted }.by(-2)
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

  context 'when activity_participation' do
    it 'validates activity_price presence when paid_missing_activity_participations is present' do
      invoice = build(:invoice, paid_missing_activity_participations: 1, activity_price: nil)
      expect(invoice).not_to have_valid(:activity_price)
    end

    it 'sets object_type to ActivityParticipation with paid_missing_activity_participations' do
      invoice = create(:invoice, :manual,
        paid_missing_activity_participations: 2,
        activity_price: 21)

      expect(invoice.object_type).to eq 'ActivityParticipation'
      expect(invoice.paid_missing_activity_participations).to eq 2
      expect(invoice.amount).to eq 42
    end
  end

  context 'when acp_share' do
    it 'sets object_type to ACPShare with acp_shares_number' do
      Current.acp.update!(share_price: 250)
      invoice = create(:invoice, :manual, acp_shares_number: -2)

      expect(invoice.object_type).to eq 'ACPShare'
      expect(invoice.acp_shares_number).to eq -2
      expect(invoice.amount).to eq -500
    end
  end

  context 'when other' do
    it 'sets items and round to five cents each item' do
      invoice = create(:invoice, :manual,
        items_attributes: {
          '0' => { description: 'Un truc cool pas cher', amount: '10.11' },
          '1' => { description: 'Un truc cool gratuit', amount: '0' },
          '2' => { description: 'Un truc cool plus cher', amount: '32.33' }
        })

      expect(invoice.object_type).to eq 'Other'
      expect(invoice.items.first.amount).to eq 10.1
      expect(invoice.items.last.amount).to eq 32.35
      expect(invoice.amount).to eq 42.45
    end

    specify 'accepts custom vat_rate' do
      Current.acp.update!(vat_membership_rate: 7.7, vat_number: 'XXX')

      invoice = create(:invoice, :manual,
        vat_rate: 2.5,
        items_attributes: {
          '0' => { description: 'Un truc cool pas cher', amount: '10' }
        })

      expect(invoice.vat_rate).to eq 2.5
      expect(invoice.amount_with_vat).to eq 10
      expect(invoice.amount_without_vat).to eq BigDecimal(9.76, 6)
      expect(invoice.vat_amount).to eq BigDecimal(0.24, 4)
    end

    specify 'accepts no vat_rate' do
      Current.acp.update!(vat_membership_rate: 7.7, vat_number: 'XXX')

      invoice = create(:invoice, :manual,
        vat_rate: '',
        items_attributes: {
          '0' => { description: 'Un truc cool pas cher', amount: '10' }
        })

      expect(invoice.vat_rate).to be_nil
      expect(invoice.amount_with_vat).to eq 10
      expect(invoice.amount_without_vat).to eq 10
      expect(invoice.vat_amount).to be_nil
    end
  end

  describe '#send!' do
    let(:invoice) { create(:invoice, :annual_fee, :open, :not_sent) }

    it 'delivers email' do
      expect { invoice.send! }
        .to change { InvoiceMailer.deliveries.size }.by(1)
      mail = InvoiceMailer.deliveries.last
      expect(mail.subject).to eq "Nouvelle facture ##{invoice.id}"
    end

    it 'touches sent_at' do
      expect { invoice.send! }.to change(invoice, :sent_at).from(nil)
    end

    it 'keeps invoice as open' do
      expect { invoice.send! }.not_to change(invoice, :state).from('open')
    end

    it 'does nothing when already sent' do
      invoice.touch(:sent_at)
      expect { invoice.send! }
        .not_to change { InvoiceMailer.deliveries.size }
    end

    it 'does nothing when all member emails are suppressed' do
      invoice.member.active_emails.each do |email|
        create(:email_suppression, email: email)
      end

      expect(invoice.member.reload.billing_emails).to eq []
      expect { invoice.send! }
        .not_to change { InvoiceMailer.deliveries.size }
    end

    it 'does nothing when member billing email is suppressed' do
      invoice.member.update!(billing_email: 'john@doe.com')
      create(:email_suppression, email: 'john@doe.com')

      expect(invoice.member.reload.billing_emails).to eq []
      expect { invoice.send! }
        .not_to change { InvoiceMailer.deliveries.size }
    end

    it 'does nothing when member has no email' do
      invoice.member.update(emails: '')
      expect { invoice.send! }
        .not_to change { InvoiceMailer.deliveries.size }
      expect(invoice.reload.sent_at).to be_nil
    end

    it 'stores sender' do
      admin = create(:admin)
      Current.session = create(:session, admin: admin)

      invoice.send!
      expect(invoice.sent_by).to eq admin
    end
  end

  describe '#mark_as_sent!' do
    let(:invoice) { create(:invoice, :annual_fee, :open, :not_sent) }

    it 'does not deliver email' do
      expect { invoice.mark_as_sent! }
        .not_to change { InvoiceMailer.deliveries.size }
    end

    it 'touches sent_at' do
      expect { invoice.mark_as_sent! }.to change(invoice, :sent_at).from(nil)
    end

    it 'keeps invoice as open' do
      expect { invoice.send! }.not_to change(invoice, :state).from('open')
    end

    it 'stores who mark it as sent' do
      admin = create(:admin)
      Current.session = create(:session, admin: admin)

      invoice.mark_as_sent!
      expect(invoice.sent_by).to eq admin
    end
  end

  describe '#cancel!' do
    let(:invoice) { create(:invoice, :annual_fee, :open) }

    it 'sets invoice as canceled' do
      expect { invoice.cancel! }
        .to change(invoice, :state).to('canceled')
    end

    it 'stores cancelor' do
      admin = create(:admin)
      Current.session = create(:session, admin: admin)

      invoice.cancel!
      expect(invoice.canceled_by).to eq admin
    end
  end

  describe 'set_vat_rate_and_amount', freeze: '2023-01-01' do
    it 'does not set it for non-membership invoices' do
      invoice = create(:invoice, :annual_fee)
      expect(invoice.vat_amount).to be_nil
      expect(invoice.vat_rate).to be_nil
    end

    it 'does not set it when ACP as no VAT set' do
      Current.acp.update!(vat_membership_rate: nil)

      invoice = create(:invoice, :membership)
      expect(invoice.vat_rate).to be_nil
      expect(invoice.vat_amount).to be_nil
    end

    it 'sets the vat_amount for membership invoice and ACP with rate set' do
      Current.acp.update!(vat_membership_rate: 7.7, vat_number: 'XXX')
      invoice = create(:invoice, :membership)

      expect(invoice.vat_rate).to eq 7.7
      expect(invoice.amount_with_vat).to eq 120
      expect(invoice.amount_without_vat).to eq BigDecimal(111.42, 6)
      expect(invoice.vat_amount).to eq BigDecimal(8.58, 4)
    end

    it 'sets the vat_amount for activity participation invoice' do
      Current.acp.update!(vat_activity_rate: 5.5, vat_number: 'XXX')
      invoice = create(:invoice,
        paid_missing_activity_participations: 2,
        activity_price: 60)

      expect(invoice.vat_rate).to eq 5.5
      expect(invoice.amount_with_vat).to eq 120
      expect(invoice.amount_without_vat).to eq BigDecimal(113.74, 6)
      expect(invoice.vat_amount).to eq BigDecimal(6.26, 4)
    end

    it 'sets the vat_amount for shop order invoice' do
      Current.acp.update!(vat_shop_rate: 2.5, vat_number: 'XXX')
      order = create(:shop_order, :pending)
      order.invoice!
      invoice = order.invoice

      expect(invoice.vat_rate).to eq 2.5
      expect(invoice.amount_with_vat).to eq 16.75
      expect(invoice.amount_without_vat).to eq BigDecimal(16.34, 6)
      expect(invoice.vat_amount).to eq BigDecimal(0.41, 4)
    end
  end

  describe '#handle_acp_shares_change!' do
    before { Current.acp.update!(share_price: 250) }

    it 'changes inactive member state to support' do
      member = create(:member, :inactive)
      expect { create(:invoice, member: member, acp_shares_number: 1) }
        .to change { member.reload.state }.from('inactive').to('support')
    end

    it 'changes support member state to inactive' do
      member = create(:member, :support_acp_share, acp_shares_number: 1)
      expect { create(:invoice, member: member, acp_shares_number: -1) }
        .to change { member.reload.state }.from('support').to('inactive')
    end
  end

  describe '#can_destroy?' do
    it 'can destroy not sent invoice' do
      invoice = create(:invoice, :annual_fee, :open, :not_sent)
      expect(invoice.can_destroy?).to eq true
    end

    it 'can not destroy not sent invoice with payments' do
      invoice = create(:invoice, :annual_fee, :open, :not_sent)
      create(:payment, invoice: invoice)
      expect(invoice.can_destroy?).to eq false
    end

    it 'can not destroy open invoice' do
      invoice = create(:invoice, :annual_fee, :open)
      expect(invoice.can_destroy?).to eq false
    end
  end

  specify '#overpaid?' do
    invoice = create(:invoice, :manual,
      items_attributes: {
        '0' => { description: 'Un truc cool pas cher', amount: '100' }
      })
    create(:invoice, :manual,
      member: invoice.member,
      items_attributes: {
        '0' => { description: 'Un truc cool pas cher', amount: '400' }
      })

    create(:payment, invoice: invoice, amount: 100)

    expect {
      create(:payment, invoice: invoice, amount: 100)
    }.to change { invoice.reload.overpaid? }.to(true)
  end

  describe '#send_overpaid_notification_to_admins!' do
    let(:member) { create(:member, name: 'Martha') }
    let(:invoice) {
      create(:invoice, :manual,
        id: 42,
        member: member,
        items_attributes: {
          '0' => { description: 'Un truc cool pas cher', amount: '100' }
        })
    }

    specify 'send notification and touch overpaid_notification_sent_at' do
      create(:payment, invoice: invoice, amount: 110)
      admin = create(:admin, name: 'John', notifications: %w[invoice_overpaid])

      expect { invoice.send_overpaid_notification_to_admins! }
        .to change { invoice.reload.overpaid_notification_sent_at }.from(nil)
        .and change { AdminMailer.deliveries.size }.by(1)

      mail = AdminMailer.deliveries.last
      expect(mail.subject).to eq 'Facture #42 payée en trop'
      expect(mail.to).to eq [admin.email]
      expect(mail.body.encoded).to include 'Salut John,'
      expect(mail.body.encoded).to include 'Martha'
    end

    specify 'when not overpaid' do
      create(:payment, invoice: invoice, amount: 100)

      expect { invoice.send_overpaid_notification_to_admins! }
        .not_to change { invoice.reload.overpaid_notification_sent_at }
      expect(AdminMailer.deliveries.size).to be_zero
    end

    specify 'when already notified' do
      create(:payment, invoice: invoice, amount: 110)
      admin = create(:admin, notifications: %w[invoice_overpaid])

      invoice.send_overpaid_notification_to_admins!
      expect(AdminMailer.deliveries.size).to eq 1

      expect {
        expect {
          invoice.reload.send_overpaid_notification_to_admins!
        }.not_to change { invoice.reload.overpaid_notification_sent_at }
      }.not_to change { AdminMailer.deliveries.size }
    end
  end

  specify 'redistribute payments after destroy' do
    member = create(:member)
    invoice1 = create(:invoice, :manual, member: member, item_price: 10, date: '2022-01-01')
    invoice2 = create(:invoice, :manual, member: member,item_price: 10, date: '2022-01-02')
    create(:payment, member: member, amount: 10)

    expect(invoice1.reload).to be_closed
    expect {
      invoice1.destroy!
    }.to change { invoice2.reload.state }.from('open').to('closed')
  end

  specify 'set creator once processed' do
    admin = create(:admin)
    Current.session = create(:session, admin: admin)
    invoice = create(:invoice, :annual_fee, :unprocessed)

    invoice.reload
    expect(invoice).to be_processed
    expect(invoice.created_by).to eq admin
  end

  specify 'closing an invoice keep track of actor' do
    member = create(:member, :active)
    invoice = create(:invoice, :open,
      member: member,
      items_attributes: { '0' => { description: 'Machin', amount: '10' } })
    expect(invoice).not_to be_closed
    expect(invoice.closed_by).to be_nil

    admin = create(:admin)
    Current.session = create(:session, admin: admin)
    create(:payment, member: member, invoice: invoice, amount: 10)

    invoice.reload
    expect(invoice.closed_by).to eq admin
    expect(invoice.closed_at).to eq invoice.audits.last.created_at
  end
end

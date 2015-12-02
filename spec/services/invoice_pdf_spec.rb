require 'rails_helper'

describe InvoicePdf do
  let(:pdf) { InvoicePdf.new(invoice, ActionController::Base.new.view_context) }
  subject { PDF::Inspector::Text.analyze(pdf.render).strings }
  let(:member) { invoice.member }
  let(:invoice) { create(:invoice) }
  let(:isr_ref) { ISRReferenceNumber.new(invoice.id, invoice.amount) }

  it { is_expected.to include "Facture N° #{invoice.id}" }
  it { is_expected.to include member.name }
  it { is_expected.to include member.address.capitalize }
  it { is_expected.to include "#{member.zip} #{member.city}" }

  it { is_expected.to include 'Banque Raiffeisen du Vignoble' }
  it { is_expected.to include '2023 Gorgier' }

  it { is_expected.to include 'Association Rage de Vert' }
  it { is_expected.to include 'Pertuis-du-Sault 1' }
  it { is_expected.to include '2001 Neuchâtel 1' }

  it { is_expected.to include "N° facture: #{invoice.id}" }
  it { is_expected.to include '01-13734-6' }

  it { is_expected.to include isr_ref.ref }
  it { is_expected.to include isr_ref.full_ref }

  context 'when only support ammount' do
    let(:invoice) { create(:invoice, support_amount: Member::SUPPORT_PRICE) }

    it { is_expected.to include 'Cotisation annuelle association' }
    it { is_expected.to include "#{Member::SUPPORT_PRICE}.00" }
  end

  context 'when support ammount + annual membership' do
    let(:invoice) do
      create(:invoice,
        support_amount: Member::SUPPORT_PRICE,
        memberships_amount: 1330,
        memberships_amounts_data: [id: 1, description: 'Foo', amount: 1330]
      )
    end

    it { is_expected.to include 'Cotisation annuelle association' }
    it { is_expected.to include "#{Member::SUPPORT_PRICE}.00" }
    it { is_expected.to include "1'330.00" }
    it { is_expected.to include 'Foo' }
    it { is_expected.to include "1'360.00" }
  end

  context 'when support ammount + quarter membership' do
    let(:invoice) do
      create(:invoice,
        support_amount: Member::SUPPORT_PRICE,
        memberships_amount: 332.50,
        memberships_amount_description: 'Montant trimestrielle #1',
        memberships_amounts_data: [id: 1, description: 'Foo', amount: 1330],
        remaining_memberships_amount: 1330
      )
    end

    it { is_expected.to include 'Cotisation annuelle association' }
    it { is_expected.to include "#{Member::SUPPORT_PRICE}.00" }
    it { is_expected.to include "1'330.00" }
    it { is_expected.to include 'Montant trimestrielle #1' }
    it { is_expected.to include 'Foo' }
    it { is_expected.to include '332.50' }
    it { is_expected.to include '362.50' }
  end

  context 'when quarter membership with change + paid amount' do
    let(:invoice) do
      create(:invoice,
        memberships_amount: 423,
        memberships_amount_description: 'Montant trimestrielle #3',
        memberships_amounts_data: [
          { id: 1, description: 'Foo1', amount: 465.50 },
          { id: 2, description: 'Foo2', amount: 1046.50 }
        ],
        paid_memberships_amount: 665,
        remaining_memberships_amount: 846
      )
    end

    it { is_expected.not_to include 'Cotisation annuelle association' }
    it { is_expected.to include 'Montant trimestrielle #3' }
    it { is_expected.to include 'Foo1' }
    it { is_expected.to include '465.50' }
    it { is_expected.to include 'Foo2' }
    it { is_expected.to include "1'046.50" }
    it { is_expected.to include '- 665.00' }
    it { is_expected.to include '846.00' }
    it { is_expected.to include '423.00' }
  end
end

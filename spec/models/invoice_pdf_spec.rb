require 'rails_helper'

describe InvoicePdf do
  let(:pdf) { InvoicePdf.new(invoice, ActionController::Base.new.view_context) }
  let(:member) { invoice.member }
  let(:invoice) { create(:invoice, :support) }
  let(:isr_ref) { ISRReferenceNumber.new(invoice.id, invoice.amount) }

  def pdf_strings
    pdf.render_file(Rails.root.join('tmp/invoice.pdf'))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  specify do
    pdf = pdf_strings
    expect(pdf).to include "Facture N° #{invoice.id}"
    expect(pdf).to include member.name
    expect(pdf).to include member.address.capitalize
    expect(pdf).to include "#{member.zip} #{member.city}"
    expect(pdf).to include 'Banque Raiffeisen du Vignoble'
    expect(pdf).to include '2023 Gorgier'
    expect(pdf).to include 'Association Rage de Vert'
    expect(pdf).to include 'Closel-Bourbon 3'
    expect(pdf).to include '2075 Thielle'
    expect(pdf).to include "N° facture: #{invoice.id}"
    expect(pdf).to include '01-13734-6'
    expect(pdf).to include isr_ref.ref
    expect(pdf).to include isr_ref.full_ref
  end

  context 'when only support ammount' do
    let(:invoice) { create(:invoice, support_amount: Member::SUPPORT_PRICE) }

    specify do
      pdf = pdf_strings

      expect(pdf).to include 'Cotisation annuelle association'
      expect(pdf).to include "#{Member::SUPPORT_PRICE}.00"
    end
  end

  context 'when support ammount + annual membership' do
    let(:membership) do
      create(:membership, basket_size_id: create(:basket_size, :big).id)
    end
    let(:invoice) do
      create(:invoice,
        support_amount: Member::SUPPORT_PRICE,
        memberships_amount_description: 'Montant annuel',
        membership: membership)
    end

    specify do
      pdf = pdf_strings

      expect(pdf).to include(/Abonnement du 01\.01\.20\d\d au 31\.12\.20\d\d \(40 livraisons\)/)
      expect(pdf).to include 'Panier: 40 x 33.25'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include 'Distribution: gratuite'
      expect(pdf).to include '0.00'
      expect(pdf).not_to include 'Demi-journées de travail'
      expect(pdf).to include 'Cotisation annuelle association'
      expect(pdf).to include "#{Member::SUPPORT_PRICE}.00"
      expect(pdf).to include 'Montant annuel'
      expect(pdf).to include 'Montant restant'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include "1'360.00"
    end
  end

  context 'when support ammount + annual membership + complements + halfday_works reduc' do
    let(:basket_complement) {
      create(:basket_complement,
        price: 3.4,
        delivery_ids: Delivery.current_year.pluck(:id))
    }
    let(:membership) do
      create(:membership,
        basket_size_id: create(:basket_size, :big).id,
        subscribed_basket_complement_ids: [basket_complement.id])
    end
    let(:invoice) do
      create(:invoice,
        support_amount: Member::SUPPORT_PRICE,
        memberships_amount_description: 'Montant annuel',
        membership: membership)
    end

    specify do
      membership.update!(
        annual_halfday_works: 8,
        halfday_works_annual_price: -330.50)
      pdf = pdf_strings

      expect(pdf).to include /Abonnement du 01\.01\.20\d\d au 31\.12\.20\d\d \(40 livraisons\)/
      expect(pdf).to include 'Panier: 40 x 33.25'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include 'Compléments: 40 x 3.40'
      expect(pdf).to include '136.00'
      expect(pdf).to include 'Distribution: gratuite'
      expect(pdf).to include '0.00'
      expect(pdf).to include 'Réduction pour 6 demi-journées de travail supplémentaires'
      expect(pdf).to include '- 330.50'
      expect(pdf).to include 'Cotisation annuelle association'
      expect(pdf).to include "#{Member::SUPPORT_PRICE}.00"
      expect(pdf).to include 'Montant annuel'
      expect(pdf).to include 'Montant restant'
      expect(pdf).to include "1'135.50"
      expect(pdf).to include "1'165.50"
    end
  end

  context 'when support ammount + quarter membership' do
    let(:member) { create(:member, billing_interval: 'annual') }
    let(:membership) do
      create(:membership,
        member: member,
        basket_size_id: create(:basket_size, :big).id,
        distribution_id: create(:distribution, price: 2).id)
    end
    let(:invoice) do
      create(:invoice,
        member: member,
        support_amount: Member::SUPPORT_PRICE,
        membership_amount_fraction: 4,
        memberships_amount_description: 'Montant trimestrielle #1',
        membership: membership)
    end

    specify do
      pdf = pdf_strings

      expect(pdf).to include /Abonnement du 01\.01\.20\d\d au 31\.12\.20\d\d \(40 livraisons\)/
      expect(pdf).to include 'Panier: 40 x 33.25'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include 'Distribution: 40 x 2.00'
      expect(pdf).to include '80.00'
      expect(pdf).not_to include 'Demi-journées de travail'
      expect(pdf).to include 'Cotisation annuelle association'
      expect(pdf).to include "#{Member::SUPPORT_PRICE}.00"
      expect(pdf).to include 'Montant trimestrielle #1'
      expect(pdf).to include '352.50'
      expect(pdf).to include '382.50'
    end
  end

  context 'when quarter menbership and paid amount' do
    let(:member) { create(:member, billing_interval: 'annual') }
    let(:membership) do
      create(:membership,
        member: member,
        basket_size_id: create(:basket_size, :big).id)
    end
    let(:invoice) do
      create(:invoice,
        date: Time.current.beginning_of_year,
        member: member,
        membership_amount_fraction: 4,
        memberships_amount_description: 'Montant trimestrielle #1',
        membership: membership)
      create(:invoice,
        date: Time.current.beginning_of_year + 4.months,
        member: member,
        membership_amount_fraction: 3,
        memberships_amount_description: 'Montant trimestrielle #2',
        membership: membership)
      create(:invoice,
        date: Time.current.beginning_of_year + 8.months,
        member: member,
        membership_amount_fraction: 2,
        memberships_amount_description: 'Montant trimestrielle #3',
        membership: membership)
    end

    specify do
      pdf = pdf_strings

      expect(pdf).not_to include 'Cotisation annuelle association'
      expect(pdf).to include 'Montant trimestrielle #3'
      expect(pdf).to include 'Panier: 40 x 33.25'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include 'Distribution: gratuite'
      expect(pdf).to include '0.00'
      expect(pdf).to include '- 665.00'
      expect(pdf).to include '665.00'
      expect(pdf).to include '332.50'
    end
  end
end

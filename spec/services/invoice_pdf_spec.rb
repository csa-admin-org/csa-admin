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
    let(:invoice) do
      create(:invoice,
        support_amount: Member::SUPPORT_PRICE,
        memberships_amount_description: 'Montant annuel',
        memberships_amounts_data: [
          id: 1,
          basket_id: 1,
          distribution_id: 1,
          basket_description: 'basket_total_description',
          basket_total_price: 1330,
          distribution_description: 'distribution_description',
          distribution_total_price: 0,
          halfday_works_description: 'halfday_works_description',
          halfday_works_total_price: 0,
          description: 'date - date (x livraisons)',
          price: 1330
        ]
      )
    end

    specify do
      pdf = pdf_strings

      expect(pdf).to include 'date - date (x livraisons)'
      expect(pdf).to include 'basket_total_description'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include 'distribution_description'
      expect(pdf).to include '0.00'
      expect(pdf).not_to include 'halfday_works_description'
      expect(pdf).to include 'Cotisation annuelle association'
      expect(pdf).to include "#{Member::SUPPORT_PRICE}.00"
      expect(pdf).to include 'Montant annuel'
      expect(pdf).to include 'Montant restant'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include "1'360.00"
    end
  end

  context 'when support ammount + annual membership + halfday_works reduc' do
    let(:invoice) do
      create(:invoice,
        support_amount: Member::SUPPORT_PRICE,
        memberships_amount_description: 'Montant annuel',
        memberships_amounts_data: [
          id: 1,
          basket_id: 1,
          distribution_id: 1,
          basket_description: 'basket_total_description',
          basket_total_price: 1330,
          distribution_description: 'distribution_description',
          distribution_total_price: 0,
          halfday_works_description: 'halfday_works_description',
          halfday_works_total_price: -330.50,
          description: 'date - date (x livraisons)',
          price: 999.50
        ]
      )
    end

    specify do
      pdf = pdf_strings

      expect(pdf).to include 'date - date (x livraisons)'
      expect(pdf).to include 'basket_total_description'
      expect(pdf).to include "1'330.00"
      expect(pdf).to include 'distribution_description'
      expect(pdf).to include '0.00'
      expect(pdf).to include 'halfday_works_description'
      expect(pdf).to include '- 330.50'
      expect(pdf).to include 'Cotisation annuelle association'
      expect(pdf).to include "#{Member::SUPPORT_PRICE}.00"
      expect(pdf).to include 'Montant annuel'
      expect(pdf).to include 'Montant restant'
      expect(pdf).to include '999.50'
      expect(pdf).to include "1'029.50"
    end
  end

  context 'when support ammount + quarter membership' do
    let(:invoice) do
      create(:invoice,
        support_amount: Member::SUPPORT_PRICE,
        memberships_amount_fraction: 4,
        memberships_amount_description: 'Montant trimestrielle #1',
        memberships_amounts_data: [
          id: 1,
          basket_id: 1,
          distribution_id: 1,
          basket_description: 'basket_total_description',
          basket_total_price: 1330.15,
          distribution_description: 'distribution_description',
          distribution_total_price: 50,
          halfday_works_description: 'halfday_works_description',
          halfday_works_total_price: 0,
          description: 'date - date (x livraisons)',
          price: 1380.15
        ]
      )
    end

    specify do
      pdf = pdf_strings

      expect(pdf).to include 'date - date (x livraisons)'
      expect(pdf).to include 'basket_total_description'
      expect(pdf).to include "1'330.15"
      expect(pdf).to include 'distribution_description'
      expect(pdf).to include '50.00'
      expect(pdf).not_to include 'halfday_works_description'
      expect(pdf).to include 'Cotisation annuelle association'
      expect(pdf).to include "#{Member::SUPPORT_PRICE}.00"
      expect(pdf).to include 'Montant trimestrielle #1'
      expect(pdf).to include '345.05'
      expect(pdf).to include '375.05'
    end
  end

  context 'when quarter mmebership with change + paid amount' do
    let(:invoice) do
      create(:invoice,
        memberships_amount_fraction: 2,
        memberships_amount_description: 'Montant trimestrielle #3',
        memberships_amounts_data: [
          {
            id: 1,
            basket_id: 1,
            distribution_id: 1,
            basket_description: 'basket_total_description',
            basket_total_price: 465.50,
            distribution_description: 'distribution_description',
            distribution_total_price: 0,
            halfday_works_description: 'halfday_works_description',
            halfday_works_total_price: 0,
            description: 'date1 - date2 (x livraisons)',
            price: 465.50
          }, {
            id: 2,
            basket_id: 2,
            distribution_id: 1,
            basket_description: 'basket_total_description',
            basket_total_price: 1046.50,
            distribution_description: 'distribution_description',
            distribution_total_price: 0,
            halfday_works_description: 'halfday_works_description',
            halfday_works_total_price: 0,
            description: 'date3 - date4 (x livraisons)',
            price: 1046.50
          }
        ],
        paid_memberships_amount: 665,
      )
    end

    specify do
      pdf = pdf_strings

      expect(pdf).not_to include 'Cotisation annuelle association'
      expect(pdf).to include 'Montant trimestrielle #3'
      expect(pdf).to include 'date1 - date2 (x livraisons)'
      expect(pdf).to include '465.50'
      expect(pdf).to include 'date3 - date4 (x livraisons)'
      expect(pdf).to include "1'046.50"
      expect(pdf).to include '- 665.00'
      expect(pdf).to include '847.00'
      expect(pdf).to include '423.50'
    end
  end
end

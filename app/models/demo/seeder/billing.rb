# frozen_string_literal: true

module Demo::Seeder::Billing
  extend ActiveSupport::Concern

  OTHER_INVOICE_ITEMS = [
    { description: { "en" => "Workshop materials", "fr" => "Matériel d'atelier", "de" => "Workshop-Material" }, amount: 25 },
    { description: { "en" => "Extra vegetables", "fr" => "Légumes supplémentaires", "de" => "Extra Gemüse" }, amount: 15 },
    { description: { "en" => "Preserving jars", "fr" => "Bocaux de conserve", "de" => "Einmachgläser" }, amount: 30 },
    { description: { "en" => "Recipe book", "fr" => "Livre de recettes", "de" => "Rezeptbuch" }, amount: 20 },
    { description: { "en" => "Farm visit donation", "fr" => "Don visite de la ferme", "de" => "Spende Hofbesuch" }, amount: 50 }
  ].freeze

  private

  def seed_invoices_and_payments!
    log "Seeding invoices and payments..."
    return if @active_members.blank?

    create_other_invoices!
    create_advance_payments!
  end

  def create_other_invoices!
    sepa_members = germany? ? @active_members.select(&:sepa?) : []
    seed_fiscal_years.each do |fy|
      members = members_with_membership_in(fy)
      next if members.empty?

      count = fy.past? ? 3 : OTHER_INVOICE_ITEMS.size
      count.times do |i|
        create_other_invoice_for!(fy, members, sepa_members, i)
      end
    end
  end

  def create_other_invoice_for!(fy, members, sepa_members, index)
    item_data = OTHER_INVOICE_ITEMS[index % OTHER_INVOICE_ITEMS.size]
    member = other_invoice_member(members, sepa_members, index)
    invoice_date = random_date_in_year(fy, latest: Date.current - 10.days)
    return unless invoice_date

    invoice = build_other_invoice(member, invoice_date, item_data)
    return unless invoice.save

    description = item_data[:description][Current.org.default_locale] || item_data[:description]["en"]
    InvoiceItem.create!(invoice: invoice, description: description, amount: item_data[:amount])
    invoice.process!(send_email: false)
    pay_other_invoice!(invoice, member, invoice_date, item_data[:amount], index, fy)
  end

  def other_invoice_member(members, sepa_members, index)
    if index.zero? && sepa_members.any? && members.include?(sepa_members.first)
      sepa_members.first
    else
      members[index % members.size]
    end
  end

  def build_other_invoice(member, invoice_date, item_data)
    invoice = Invoice.new(member: member, date: invoice_date, sent_at: invoice_date)
    invoice[:entity_type] = "Other"
    invoice[:amount] = item_data[:amount]
    invoice[:vat_rate] = 0
    invoice[:vat_amount] = 0
    invoice
  end

  def pay_other_invoice!(invoice, member, invoice_date, amount, index, fy)
    fully_paid = fy.past? || index < 3
    partially_paid = !fy.past? && index == 3
    return unless fully_paid || partially_paid

    payment_amount = fully_paid ? amount : (amount * 0.5).round
    payment_date = [ invoice_date + rand(5..20).days, Date.current ].min
    payment_date = invoice_date if payment_date < invoice_date
    Payment.create!(
      member: member,
      invoice: invoice,
      amount: payment_amount,
      date: payment_date,
      origin: "camt")
  end

  def create_advance_payments!
    fiscal_year = Current.fiscal_year
    earliest_date = fiscal_year.beginning_of_year
    latest_date = [ Date.current - 5.days, earliest_date ].max
    payment_range = earliest_date..[ latest_date, Date.current ].min
    @active_members.sample(3).each_with_index do |member, i|
      Payment.create!(
        member: member,
        amount: [ 200, 350, 500 ][i],
        date: rand(payment_range),
        origin: "manual")
    end
  end

  def ensure_invoice_pdfs_uploaded!
    log "Ensuring invoice PDFs are on storage..."
    Invoice.joins(:pdf_file_attachment).with_attached_pdf_file.find_each do |invoice|
      next if invoice_pdf_on_storage?(invoice)

      invoice.attach_pdf
    end
  end

  def invoice_pdf_on_storage?(invoice)
    blob = invoice.pdf_file.blob
    blob.present? && blob.service.exist?(blob.key)
  end

  def ensure_sepa_mandate_pdfs_uploaded!
    log "Ensuring SEPA mandate PDFs are on storage..."
    SEPAMandate.joins(:pdf_attachment).with_attached_pdf.find_each do |mandate|
      next if mandate.pdf_on_storage?

      mandate.generate_pdf!
    end
  end
end

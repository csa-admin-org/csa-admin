class TranslateAcpsColumns < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :invoice_infos, :jsonb, default: {}, null: false
    add_column :acps, :invoice_footers, :jsonb, default: {}, null: false
    add_column :acps, :delivery_pdf_footers, :jsonb, default: {}, null: false
    add_column :acps, :terms_of_service_urls, :jsonb, default: {}, null: false

    if Tenant.outside?
      ACP.find_each do |acp|
        invoice_infos = acp.languages.map { |l| [ l, acp[:invoice_info] ] }.to_h
        invoice_footers = acp.languages.map { |l| [ l, acp[:invoice_footer] ] }.to_h
        delivery_pdf_footers = acp.languages.map { |l| [ l, acp[:delivery_pdf_footer] ] }.to_h
        terms_of_service_urls = acp.languages.map { |l| [ l, acp[:terms_of_service_url] ] }.to_h
        acp.update_columns(
          invoice_infos: invoice_infos,
          invoice_footers: invoice_footers,
          delivery_pdf_footers: delivery_pdf_footers,
          terms_of_service_urls: terms_of_service_urls)
      end
    end

    remove_column :acps, :invoice_info
    remove_column :acps, :invoice_footer
    remove_column :acps, :delivery_pdf_footer
    remove_column :acps, :terms_of_service_url
  end
end

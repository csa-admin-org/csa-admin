# frozen_string_literal: true

class TranslateAcpsColumns < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :invoice_infos, :jsonb, default: {}, null: false
    add_column :acps, :invoice_footers, :jsonb, default: {}, null: false
    add_column :acps, :delivery_pdf_footers, :jsonb, default: {}, null: false
    add_column :acps, :terms_of_service_urls, :jsonb, default: {}, null: false

    if Tenant.outside?
      Organization.find_each do |org|
        invoice_infos = org.languages.map { |l| [ l, org[:invoice_info] ] }.to_h
        invoice_footers = org.languages.map { |l| [ l, org[:invoice_footer] ] }.to_h
        delivery_pdf_footers = org.languages.map { |l| [ l, org[:delivery_pdf_footer] ] }.to_h
        terms_of_service_urls = org.languages.map { |l| [ l, org[:terms_of_service_url] ] }.to_h
        org.update_columns(
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

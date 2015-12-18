require 'google_access_token_fetcher'
require 'facets/string/similarity'

class InvoicesImporter
  attr_reader :invoices

  def self.import
    new.import
  end

  def initialize
    access_token = GoogleAccessTokenFetcher.access_token
    session = GoogleDrive.login_with_oauth(access_token)
    csv_string = session.file_by_title('Factures2').download_to_string
    csv_string = csv_string.unpack("C*").pack("U*")
    @invoices = parse_csv(csv_string)
  end

  def import
    invoices.each do |invoice_hash|
      if member = find_member(invoice_hash)
        create_or_update_invoice(member, invoice_hash)
      end
    end
  end

  private

  def parse_csv(csv_string)
    rows = CSV.parse csv_string, col_sep: "\t"
    keys = rows.shift
    rows.map do |row|
      Hash[row.each_with_index.map { |el, i| [keys[i], el] }]
    end
  end

  def find_member(invoice_hash)
    identifier = invoice_hash['N° client']
    Member.find_by_old_invoice_identifier(identifier) || guess_member(invoice_hash)
  end

  def guess_member(invoice_hash)
    name = "#{invoice_hash['Prénom']} #{invoice_hash['Nom/société']}"
    p "---- #{name} (#{invoice_hash['Code postal']}) - #{invoice_hash['N° client']} ----"
    members = Member.all.sort_by { |m| m.name.similarity(name) }
    if members.present? && members.last.name.similarity(name) > 0.7
      member = members.last
      p "Found: #{member.name}"
      member.update!(old_invoice_identifier: invoice_hash['N° client'])
      member
    else
      p "NOT FOUND"
      members.last(5).reverse.each do |m|
        p "#{m.name} - #{m.name.similarity(name).round(2)} - #{m.id}"
      end
      nil
    end
  end

  def create_or_update_invoice(member, hash)
    invoice = Invoice.find_or_initialize_by(number: hash['N° document'])
    invoice.update!(
      member: member,
      date: hash['Date pièce'],
      amount: hash['total'].try(:tr, ',', '.').to_f,
      balance: hash['Solde'].try(:tr, ',', '.').to_f,
      data: {
        identifier: hash['N° client'],
        first_name: hash['Prénom'],
        last_name: hash['Nom/société'],
        zip: hash['Code postal'],
        city: hash['Ville']
      }
    )
  end
end

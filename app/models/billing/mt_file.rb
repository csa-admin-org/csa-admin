# frozen_string_literal: true

module Billing
  class MtFile
    UnsupportedFileError = Class.new(StandardError)
    PaymentData = Class.new(OpenStruct)

    def self.process!(file)
      data = new(file).payments_data
      PaymentsProcessor.new(data).process!
    end

    def initialize(*files)
      @files = Array(*files)
    end

    def payments_data
      @files.flat_map { |file|
        statements = Cmxl.parse(File.read(file), encoding: "ISO-8859-1")
        statements.flat_map { |statement|
          statement.transactions.map { |transaction|
            if transaction.credit?
              date = transaction.date
              ref = extract_ref(transaction.information)
              if ref && Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                PaymentData.new(
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: transaction.amount,
                  date: date,
                  fingerprint: "#{date}-#{transaction.sha}-#{ref}")
              end
            end
          }
        }
      }.compact
    rescue Cmxl::Field::LineFormatError, ArgumentError => e
      Error.report(e, file: @files.first)
      raise UnsupportedFileError, e.message
    end

    private

    def extract_ref(string)
      if Current.org.swiss_qr?
        bank_ref = Current.org.bank_reference
        string[/#{bank_ref}\d{#{27 - bank_ref.length}}/i]
      else
        string.gsub(/\W/, "")[/RF\d{18}/i]
      end
    end
  end
end

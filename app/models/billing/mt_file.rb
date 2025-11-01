# frozen_string_literal: true

require "ostruct"
require "cmxl"

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
      origin = "mt940"
      @files.flat_map { |file|
        statements = Cmxl.parse(File.read(file), encoding: "ISO-8859-1")
        statements.flat_map { |statement|
          statement.transactions.map { |transaction|
            if transaction.credit?
              date = transaction.date
              ref = Billing.reference.extract_ref(transaction.information)
              if ref && Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                sign = transaction.reversal? ? -1 : 1
                PaymentData.new(
                  origin: origin,
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: sign * transaction.amount,
                  date: date)
              end
            end
          }
        }
      }.compact
    rescue Cmxl::Field::LineFormatError, ArgumentError => e
      Error.report(e, file: @files.first)
      raise UnsupportedFileError, e.message
    end
  end
end

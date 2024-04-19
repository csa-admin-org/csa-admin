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
              ref = transaction.information.gsub(/\W/, "")[/RF\d{18}/i]
              if Billing.reference.valid?(ref)
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
      Sentry.capture_exception(e, extra: { file: @files.first })
      raise UnsupportedFileError, e.message
    end
  end
end

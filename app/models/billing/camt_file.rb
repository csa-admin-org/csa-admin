module Billing
  class CamtFile
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
        camt54 = CamtParser::String.parse(file)
        if CamtParser::Format054::Base === camt54
          camt54.notifications.flat_map { |notification|
            notification.entries.flat_map { |entry|
              date = entry.value_date
              entry.transactions.map { |transaction|
                ref = transaction.creditor_reference
                if transaction.credit? && ref.present?
                  bank_ref = transaction.bank_reference
                  PaymentData.new(
                    invoice_id: ref.last(10).first(9).to_i,
                    amount: transaction.amount,
                    date: date,
                    isr_data: "#{date}-#{bank_ref}-#{ref}")
                end
              }.compact
            }
          }
        else
          raise UnsupportedFileError, "Invalid format: #{camt54.class.name}"
        end
      # Handle identical payment (same date, same ref, same amount)
      }.group_by(&:isr_data).flat_map { |_, dd|
        dd.each_with_index.map { |d, i|
          d.isr_data += "-#{i}" if i > 0
          d
        }
      }
    rescue CamtParser::Errors::UnsupportedNamespaceError, ArgumentError => e
      Sentry.capture_exception(e, extra: { file: @files.first.read })
      raise UnsupportedFileError, e.message
    end
  end
end

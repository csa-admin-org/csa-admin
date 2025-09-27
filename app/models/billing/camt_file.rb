# frozen_string_literal: true

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
        camt = CamtParser::String.parse(file)
        case camt
        when CamtParser::Format054::Base; parse_camt54(camt)
        when CamtParser::Format053::Base; parse_camt53(camt)
        else
          raise UnsupportedFileError, "Invalid format: #{camt54.class.name}"
        end
        # Handle identical payment (same date, same ref, same amount)
      }.group_by(&:fingerprint).flat_map { |_, dd|
        amounts_count = dd.map(&:amount).uniq.size
        dd.each_with_index.map { |d, i|
          d.fingerprint += "-#{i}" if i > 0 and amounts_count > 1
          d
        }
      }.compact.uniq(&:fingerprint)
    rescue CamtParser::Errors::UnsupportedNamespaceError, ArgumentError => e
      Error.report(e, file: @files.first.read)
      raise UnsupportedFileError, e.message
    end

    private

    def parse_camt54(camt)
      camt.notifications.flat_map { |notification|
        notification.entries.flat_map { |entry|
          date = entry.value_date
          entry.transactions.map { |transaction|
            ref = transaction.creditor_reference
            if transaction.credit?
              bank_ref = transaction.bank_reference
              if Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                PaymentData.new(
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: transaction.amount,
                  date: date,
                  fingerprint: "#{date}-#{bank_ref}-#{ref}")
              elsif Billing.reference.unknown?(ref)
                Rails.event.notify(:unknown_payment_reference,
                  type: "camt54",
                  ref: ref,
                  bank_ref: bank_ref,
                  amount: transaction.amount,
                  date: date)
                nil
              end
            end
          }.compact
        }
      }
    end

    def parse_camt53(camt)
      camt.statements.flat_map { |statement|
        statement.entries.flat_map { |entry|
          date = entry.value_date

          entry.transactions.map { |transaction|
            ref = transaction.remittance_information
            if transaction.credit?
              bank_ref =
                transaction.bank_reference.presence ||
                transaction.transaction_id.presence ||
                "NOBANKREF"
              if Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                PaymentData.new(
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: transaction.amount,
                  date: date,
                  fingerprint: "#{date}-#{bank_ref}-#{ref}")
              elsif Billing.reference.unknown?(ref)
                Rails.event.notify(:unknown_payment_reference,
                  type: "camt53",
                  ref: ref,
                  transaction_id: bank_ref,
                  amount: transaction.amount,
                  date: date)
                nil
              end
            end
          }.compact
        }
      }
    end
  end
end

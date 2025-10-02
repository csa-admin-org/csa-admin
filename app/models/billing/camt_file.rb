# frozen_string_literal: true

module Billing
  class CamtFile
    UnsupportedFileError = Class.new(StandardError)
    PaymentData = Class.new(OpenStruct)

    REVERSAL_TEXTS = [ "Retourenbelastung" ]

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
      }
    rescue CamtParser::Errors::UnsupportedNamespaceError, ArgumentError => e
      Error.report(e, file: @files.first.read)
      raise UnsupportedFileError, e.message
    end

    private

    def parse_camt54(camt)
      origin = "camt.054"
      camt.notifications.flat_map { |notification|
        notification.entries.flat_map { |entry|
          date = entry.value_date
          entry.transactions.map { |transaction|
            ref = transaction.creditor_reference
            if transaction.credit?
              if Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                PaymentData.new(
                  origin: origin,
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: transaction.amount,
                  date: date)
              elsif Billing.reference.unknown?(ref)
                Rails.event.notify(:unknown_payment_reference,
                  origin: origin,
                  amount: transaction.amount,
                  date: date,
                  ref: ref)
                nil
              end
            end
          }.compact
        }
      }
    end

    def parse_camt53(camt)
      origin = "camt.053"
      camt.statements.flat_map { |statement|
        statement.entries.flat_map { |entry|
          date = entry.value_date

          entry.transactions.map { |transaction|
            ref = transaction.remittance_information
            if transaction.credit?
              if Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                PaymentData.new(
                  origin: origin,
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: transaction.amount,
                  date: date)
              elsif Billing.reference.unknown?(ref)
                Rails.event.notify(:unknown_payment_reference,
                  origin: origin,
                  amount: transaction.amount,
                  date: date,
                  ref: ref)
                nil
              end
            elsif transaction.debit? && entry.additional_information.in?(REVERSAL_TEXTS)
              if Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                ref = Billing.reference.extract_ref(ref)
                PaymentData.new(
                  origin: origin,
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: -1 * transaction.amount,
                  date: date)
              elsif Billing.reference.unknown?(ref)
                Rails.event.notify(:unknown_reversal_payment_reference,
                  origin: origin,
                  amount: transaction.amount,
                  date: date,
                  ref: ref)
                nil
              end
            end
          }.compact
        }
      }
    end
  end
end

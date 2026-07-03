# frozen_string_literal: true

class BankConnection
  class RuntimeAdapter
    delegate_missing_to :adapter

    def initialize(connection, adapter)
      @connection = connection
      @adapter = adapter
    end

    def process_payments!
      connection.mark_import_attempted!(operation: payment_import_operation)
      payments_data = adapter.payments_data
      result = Billing::PaymentsProcessor.new(payments_data).process!
      mark_import_completed!(payments_data)
      result
    rescue => e
      connection.mark_error!(e, operation: payment_import_operation, operation_kind: "payment_import")
      Rails.error.report(e, context: connection.safe_context(operation: payment_import_operation, operation_kind: "payment_import"))
      raise
    end

    def sepa_direct_debit_upload(document)
      connection.mark_upload_attempted!(operation: sepa_upload_operation)
      result = adapter.sepa_direct_debit_upload(document)
      connection.mark_upload_succeeded!(operation: sepa_upload_operation, order_id: result_order_id(result))
      result
    rescue => e
      connection.mark_error!(e, operation: sepa_upload_operation, operation_kind: "sepa_direct_debit_upload")
      Rails.error.report(e, context: connection.safe_context(operation: sepa_upload_operation, operation_kind: "sepa_direct_debit_upload"))
      raise
    end

    private

    attr_reader :connection, :adapter

    def mark_import_completed!(payments_data)
      if payments_data.present?
        connection.mark_import_succeeded!(operation: payment_import_operation, payments_count: payments_data.size)
      else
        connection.mark_no_data!(operation: payment_import_operation)
      end
    end

    def payment_import_operation
      provider_operation("payment_import")
    end

    def sepa_upload_operation
      provider_operation("sepa_direct_debit_upload")
    end

    def provider_operation(kind)
      { "mode" => "provider_api", "provider" => connection.provider, "kind" => kind }
    end

    def result_order_id(result)
      Array(result).second
    end
  end
end

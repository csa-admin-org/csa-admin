# frozen_string_literal: true

module Billing
  class EBICS
    class ClientError < StandardError
      attr_reader :original_error

      def initialize(original_error)
        @original_error = original_error
        super(original_error.message)
      end
    end

    NoDownloadDataAvailable = Class.new(ClientError)
    TechnicalError = Class.new(ClientError)
    UnsupportedOperation = Class.new(StandardError)
    MaintenanceError = Class.new(StandardError)

    GET_PAYMENTS_FROM = 1.month.ago

    attr_reader :credentials, :operation_config

    def initialize(credentials = {}, settings: {}, ebics_client: nil, bank_connection: nil)
      @credentials = Credentials.new(credentials)
      @operation_config = OperationConfig.new(settings)
      @ebics_client = ebics_client
      @bank_connection = bank_connection
    end

    def payments_data
      files = get_camt_files
      CamtFile.new(files).payments_data
    rescue MaintenanceError
      []
    end

    def process_payments!
      operation = operation_config.payment_download
      process_btf_payments!(operation)
    rescue UnsupportedOperation => e
      report_configuration_error(e, operation: nil, operation_kind: "payment_download")
      raise
    rescue MaintenanceError
      Billing::PaymentsProcessor.new([]).process!
    end

    def sepa_direct_debit_upload(document)
      operation = operation_config.sepa_direct_debit_upload
      @bank_connection&.mark_upload_attempted!(operation: operation)

      result = ebics_client(operation).upload(operation, document: document)
      @bank_connection&.mark_upload_succeeded!(operation: operation, order_id: upload_order_id(result))
      result
    rescue UnsupportedOperation => e
      report_configuration_error(e, operation: operation, operation_kind: "sepa_direct_debit_upload")
      raise
    rescue => e
      @bank_connection&.mark_error!(e, operation: operation, operation_kind: "sepa_direct_debit_upload")
      raise
    end

    def sepa_direct_debit_schema
      operation_config.sepa_direct_debit_upload_schema
    end

    private

    def get_camt_files
      operation = operation_config.payment_download
      @bank_connection&.mark_import_attempted!(operation: operation)

      files = ebics_client(operation).download(
        operation,
        from: payments_from,
        to: payments_to)
      @bank_connection&.mark_import_succeeded!(operation: operation, files_count: files.size)
      files
    rescue NoDownloadDataAvailable => e
      @bank_connection&.mark_no_data!(operation: operation)
      notify(:ebics_no_data_available, e.original_error)
      []
    rescue TechnicalError => e
      @bank_connection&.mark_error!(e.original_error, operation: operation, operation_kind: "payment_download")
      notify(:ebics_technical_error, e.original_error)
      report_technical_error(e, operation, "payment_download")
      raise MaintenanceError, "EBICS technical error occurred"
    end

    def process_btf_payments!(operation)
      files_count = nil
      @bank_connection&.mark_import_attempted!(operation: operation)

      result = ebics_client(operation).download_and_process(operation, from: payments_from, to: payments_to) do |files|
        files_count = files.size
        Billing::PaymentsProcessor
          .new(CamtFile.new(files).payments_data, raise_on_error: true)
          .process!
      end
      @bank_connection&.mark_import_succeeded!(operation: operation, files_count: files_count)
      result
    rescue NoDownloadDataAvailable => e
      @bank_connection&.mark_no_data!(operation: operation)
      notify(:ebics_no_data_available, e.original_error)
      Billing::PaymentsProcessor.new([]).process!
    rescue TechnicalError => e
      @bank_connection&.mark_error!(e.original_error, operation: operation, operation_kind: "payment_download")
      notify(:ebics_technical_error, e.original_error)
      report_technical_error(e, operation, "payment_download")
      raise MaintenanceError, "EBICS technical error occurred"
    rescue => e
      @bank_connection&.mark_error!(e, operation: operation, operation_kind: "payment_download")
      raise
    end

    def payments_from
      GET_PAYMENTS_FROM.to_date.to_s
    end

    def payments_to
      Date.current.to_s
    end

    def ebics_client(_operation)
      @ebics_client || btf_client
    end

    def btf_client
      @btf_client ||= BtfClient.new(
        credentials,
        context: safe_context)
    end

    def upload_order_id(result)
      result.is_a?(Array) ? result.second : result
    end

    def notify(name, error)
      Rails.event.notify(name,
        **safe_context(
          error: error.class.name,
          error_message: error.message).symbolize_keys)
    end

    def report_technical_error(error, operation, operation_kind)
      Rails.error.report(error.original_error,
        context: safe_context(
          operation: operation,
          operation_kind: operation_kind,
          error: error.class.name,
          error_message: error.message))
    end

    def report_configuration_error(error, operation:, operation_kind:)
      @bank_connection&.mark_error!(error, operation: operation, operation_kind: operation_kind)
      Rails.error.report(error,
        context: safe_context(
          operation: operation,
          operation_kind: operation_kind,
          error: error.class.name,
          error_message: error.message))
    end

    def safe_context(operation: nil, **context)
      SafeContext.build(
        connection: @bank_connection,
        operation: operation,
        **context)
    end
  end
end

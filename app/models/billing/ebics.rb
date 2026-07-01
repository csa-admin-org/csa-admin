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

    def initialize(credentials = {}, settings: {}, ebics_client: nil)
      @credentials = Credentials.new(credentials)
      @operation_config = OperationConfig.new(settings)
      @ebics_client = ebics_client
    end

    def payments_data
      files = get_camt_files
      CamtFile.new(files).payments_data
    rescue MaintenanceError
      []
    end

    def sepa_direct_debit_upload(document)
      ebics_client.upload(operation_config.sepa_direct_debit_upload, document: document)
    end

    def client
      ebics_client.client
    end

    private
      def get_camt_files
        ebics_client.download(
          operation_config.payment_download(country_code: Current.org.country_code),
          from: GET_PAYMENTS_FROM.to_date.to_s,
          to: Date.current.to_s)
      rescue NoDownloadDataAvailable => e
        notify(:ebics_no_data_available, e.original_error)
        []
      rescue TechnicalError => e
        notify(:ebics_technical_error, e.original_error)
        raise MaintenanceError, "EBICS technical error occurred"
      end

      def ebics_client
        @ebics_client ||= LegacyClient.new(credentials)
      end

      def notify(name, error)
        Rails.event.notify(name,
          error: error.class.name,
          error_message: error.message)
      end
  end
end

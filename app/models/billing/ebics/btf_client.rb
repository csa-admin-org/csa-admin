# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    class BtfClient
      TestDownloadResult = Data.define(:status, :files, :acknowledged, :receipt_code) do
        def to_h
          {
            "status" => status,
            "files_count" => files.size,
            "bytes" => files.sum(&:bytesize),
            "acknowledged" => acknowledged,
            "receipt_code" => receipt_code
          }
        end
      end

      AdminOrderResult = Data.define(:order_data, :receipt_sent)
      AdminOrderDataError = Class.new(StandardError)

      class ResponseError < StandardError
        attr_reader :response

        def initialize(response)
          @response = response
          super([ response.return_code, response.report_text ].compact_blank.join(" "))
        end
      end

      VerificationError = Class.new(StandardError)

      def initialize(credentials, key_store: KeyStore.new(credentials), request_options: {}, transport: Btf::Transport.new, verify_signatures: true, context: {}, error_reporter: Rails.error)
        @credentials = Credentials.new(credentials)
        @key_store = key_store
        @request_options = request_options
        @transport = transport
        @verify_signatures = verify_signatures
        @context = context
        @error_reporter = error_reporter
      end

      def client
        key_store
      end

      def download(_operation, from:, to:)
        raise UnsupportedOperation,
          "Use download_and_process for H005/BTF imports so returned data is acknowledged only after processing succeeds"
      end

      def download_and_process(operation, from:, to:)
        processed = false
        responses = download_responses(operation, from: from, to: to)
        files = files_from_responses(operation, responses)
        result = yield files
        processed = true
        send_receipt!(responses.last.transaction_id, Btf::ReceiptRequest::SUCCESS_CODE) if receipt_required?(responses)
        result
      rescue NoDownloadDataAvailable
        raise
      rescue => e
        safely_send_failure_receipt(responses) if defined?(responses) && !processed
        raise e
      end

      def test_download(operation, from:, to:, acknowledge: false)
        responses = download_responses(operation, from: from, to: to)
        files = files_from_responses(operation, responses)
        receipt_code = acknowledge ? Btf::ReceiptRequest::SUCCESS_CODE : Btf::ReceiptRequest::FAILURE_CODE
        send_receipt!(
          responses.last.transaction_id,
          receipt_code,
          allow_download_postprocess_skipped: !acknowledge) if receipt_required?(responses)

        TestDownloadResult.new(
          status: acknowledge ? "data_acknowledged" : "data_available_not_acknowledged",
          files: files,
          acknowledged: acknowledge,
          receipt_code: receipt_code)
      rescue NoDownloadDataAvailable
        TestDownloadResult.new(
          status: "no_data",
          files: [],
          acknowledged: true,
          receipt_code: nil)
      end

      def upload(operation, document:)
        ensure_btf_upload!(operation)
        initialisation_request = upload_request(operation, document: document)
        initialisation_response = post_request(initialisation_request)
        raise_response_error!(initialisation_response)

        initialisation_transaction_id = require_response_value!(
          initialisation_response,
          :transaction_id,
          "Missing EBICS BTU initialisation TransactionID",
          operation: operation)

        transfer_response = post_request(upload_transfer_request(
          initialisation_transaction_id,
          initialisation_request.payload))
        raise_response_error!(transfer_response)

        transaction_id = transfer_response.transaction_id.presence || initialisation_transaction_id
        order_id = transfer_response.order_id.presence || initialisation_response.order_id
        require_value!(transaction_id, "Missing EBICS BTU upload TransactionID", operation: operation, response: transfer_response)
        require_value!(order_id, "Missing EBICS BTU upload OrderID", operation: operation, response: transfer_response)

        [ transaction_id, order_id ]
      end

      def admin_order(order_type)
        validated = false
        responses = admin_responses(order_type)
        order_data = Btf::Payload.new(responses: responses).order_data
        validate_admin_order_data!(order_type, order_data)
        validated = true
        receipt_sent = receipt_required?(responses)
        send_receipt!(responses.last.transaction_id, Btf::ReceiptRequest::SUCCESS_CODE) if receipt_sent

        AdminOrderResult.new(order_data: order_data, receipt_sent: receipt_sent)
      rescue => e
        safely_send_failure_receipt(responses) if defined?(responses) && !validated
        raise e
      end

      def admin_order_data(order_type)
        admin_order(order_type).order_data
      end

      def admin_request_xml(order_type, **overrides)
        admin_request(order_type, **overrides).to_xml
      end

      def download_request_xml(operation, from:, to:, **overrides)
        download_request(operation, from: from, to: to, **overrides).to_xml
      end

      def upload_request_xml(operation, document:, **overrides)
        upload_request(operation, document: document, **overrides).to_xml
      end

      def upload_transfer_request_xml(transaction_id:, document:, **overrides)
        payload = Btf::UploadPayload.new(client: client, document: document)
        upload_transfer_request(transaction_id, payload, **overrides).to_xml
      end

      def download_request(operation, from:, to:, **overrides)
        ensure_btf_download!(operation)

        Btf::DownloadRequest.new(
          client: client,
          operation: operation,
          from: from,
          to: to,
          **request_options.merge(overrides))
      end

      def files_from_response(operation, response_xml)
        files_from_responses(operation, [ response_from(response_xml) ])
      end

      def files_from_responses(operation, responses)
        ensure_btf_download!(operation)
        raise_response_error!(responses.last)

        Btf::Payload.new(responses: responses, container: operation.btf["container"]).files
      end

      private

      attr_reader :credentials, :key_store, :request_options, :transport, :verify_signatures, :context, :error_reporter

      def download_responses(operation, from:, to:)
        ensure_btf_download!(operation)
        order_responses(download_request(operation, from: from, to: to))
      end

      def admin_responses(order_type)
        order_responses(admin_request(order_type))
      end

      def order_responses(request)
        [].tap do |responses|
          response = post_request(request)
          raise_response_error!(response)
          responses << response

          while response.segmented? && !response.last_segment?
            response = post_request(transfer_request(
              require_response_value!(
                response,
                :transaction_id,
                "Missing EBICS BTD transfer TransactionID"),
              response.next_segment_number))
            raise_response_error!(response)
            responses << response
          end
        end
      end

      def post_request(request)
        response_from(transport.post(credentials.url, request.to_xml))
      end

      def response_from(response_xml)
        Btf::Response.new(client: client, xml: response_xml).tap { |response| verify_response!(response) }
      end

      def admin_request(order_type, **overrides)
        Btf::AdminRequest.new(
          client: client,
          order_type: order_type,
          **request_options.merge(overrides))
      end

      def upload_request(operation, document:, **overrides)
        ensure_btf_upload!(operation)

        Btf::UploadRequest.new(
          client: client,
          operation: operation,
          document: document,
          **request_options.merge(overrides))
      end

      def upload_transfer_request(transaction_id, payload, **overrides)
        Btf::UploadTransferRequest.new(
          client: client,
          transaction_id: transaction_id,
          payload: payload,
          **{ signer: request_options[:signer] }.merge(overrides))
      end

      def validate_admin_order_data!(order_type, order_data)
        expected_root = {
          "HAA" => "HAAResponseOrderData",
          "HTD" => "HTDResponseOrderData"
        }.fetch(order_type.to_s.upcase)
        root_name = Nokogiri::XML(order_data).root&.name
        return if root_name == expected_root

        report_unexpected("Unexpected EBICS admin-order response data",
          admin_order_type: order_type.to_s.upcase,
          expected_root: expected_root,
          root: root_name)
        raise AdminOrderDataError, "Unexpected #{order_type.to_s.upcase} response order data"
      end

      def transfer_request(transaction_id, segment_number)
        Btf::TransferRequest.new(
          client: client,
          transaction_id: transaction_id,
          segment_number: segment_number,
          signer: request_options[:signer])
      end

      def send_receipt!(transaction_id, receipt_code, allow_download_postprocess_skipped: false)
        response = response_from(transport.post(credentials.url, receipt_request(transaction_id, receipt_code).to_xml))
        return if allow_download_postprocess_skipped && response.download_postprocess_skipped?

        raise_response_error!(response)
      end

      def safely_send_failure_receipt(responses)
        return unless receipt_required?(responses)

        send_receipt!(
          responses.last.transaction_id,
          Btf::ReceiptRequest::FAILURE_CODE,
          allow_download_postprocess_skipped: true)
      rescue
        nil
      end

      def receipt_request(transaction_id, receipt_code)
        Btf::ReceiptRequest.new(
          client: client,
          transaction_id: transaction_id,
          receipt_code: receipt_code,
          signer: request_options[:signer])
      end

      def receipt_required?(responses)
        responses&.last&.transaction_id.present? && responses.any?(&:order_data_present?)
      end

      def require_response_value!(response, method_name, message, operation: nil)
        require_value!(
          response.public_send(method_name),
          message,
          operation: operation,
          response: response)
      end

      def require_value!(value, message, operation: nil, response: nil)
        return value if value.present?

        report_unexpected(message,
          operation: operation,
          response: response)
        raise TechnicalError.new(VerificationError.new(message))
      end

      def report_unexpected(message, operation: nil, response: nil, **extra)
        Billing::EBICS::SafeContext.report_unexpected(message,
          reporter: error_reporter,
          context: context.merge(
            Billing::EBICS::SafeContext.build(
              operation: operation,
              response: response_context(response),
              **extra)))
      end

      def response_context(response)
        return unless response

        {
          "return_code" => response.return_code,
          "report_text" => response.report_text,
          "transaction_id_present" => response.transaction_id.present?,
          "order_id_present" => response.order_id.present?
        }
      end

      def raise_response_error!(response)
        response_error = ResponseError.new(response)

        raise NoDownloadDataAvailable.new(response_error) if response.no_download_data?
        raise TechnicalError.new(response_error) if response.technical_error?
        raise ClientError.new(response_error) if response.business_error?
      end

      def verify_response!(response)
        return unless verify_signatures
        return if response.digest_valid? && response.signature_valid?

        raise TechnicalError.new(VerificationError.new("Invalid EBICS response signature"))
      end

      def ensure_btf_download!(operation)
        return if operation.btf? && operation.order_type == "BTD"

        raise UnsupportedOperation,
          "H005/BTF client only supports BTD download operations"
      end

      def ensure_btf_upload!(operation)
        return if operation.btf? && operation.order_type == "BTU"

        raise UnsupportedOperation,
          "H005/BTF client only supports BTU upload operations"
      end
    end
  end
end

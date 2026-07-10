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
      MAX_RESPONSE_SEGMENTS = 100
      MAX_CUMULATIVE_RESPONSE_BYTES = Btf::Transport::MAX_RESPONSE_BYTES
      MAX_CUMULATIVE_ENCODED_ORDER_DATA_BYTES = Btf::Response::MAX_ENCODED_ORDER_DATA_BYTES
      MAX_CUMULATIVE_ENCRYPTED_ORDER_DATA_BYTES = Btf::Payload::MAX_ENCRYPTED_ORDER_DATA_BYTES
      InvalidResponseError = Class.new(StandardError)
      SetupOrderResult = Data.define(:order_type, :transaction_id, :order_id) do
        def to_h
          {
            "order_type" => order_type,
            "transaction_id" => transaction_id,
            "order_id" => order_id
          }.compact_blank
        end
      end
      BankPublicKeysResult = Data.define(:keys, :order_data, :receipt_sent) do
        def to_h
          {
            "receipt_sent" => receipt_sent,
            "bank_keys" => keys.to_h
          }
        end
      end
      KeyChangeResult = Data.define(:transaction_id, :order_id) do
        def to_h
          {
            "transaction_id" => transaction_id,
            "order_id" => order_id
          }.compact_blank
        end
      end
      AdminOrderDataError = Class.new(StandardError)

      class ResponseError < StandardError
        attr_reader :response

        def initialize(response)
          @response = response
          super("EBICS response #{response.return_code.presence || "unknown"}")
        end
      end

      class AdminOrderDataProfile
        ROOTS = {
          "HAA" => "HAAResponseOrderData",
          "HTD" => "HTDResponseOrderData"
        }.freeze

        def self.valid?(order_type, xml)
          expected_root = ROOTS[order_type.to_s.upcase]
          expected_root && Btf::SchemaValidator.valid?(xml, schema: :orders, root: expected_root)
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

      def key_change_request_xml(target_key_store:, order_type: "HCS", **overrides)
        key_change_request(target_key_store: target_key_store, order_type: order_type, **overrides).to_xml
      end

      def key_change_order_data_xml(target_key_store:, order_type: "HCS")
        Btf::KeyChangeOrderData.new(client: target_key_store, order_type: order_type).to_xml
      end

      def initialization_order_data_xml(order_type, **overrides)
        Btf::InitializationOrderData.new(
          client: client,
          order_type: order_type,
          **setup_order_data_options.merge(overrides)).to_xml
      end

      def initialization_request_xml(order_type, **overrides)
        initialization_request(order_type, **overrides).to_xml
      end

      def submit_initialization_order(order_type)
        request = initialization_request(order_type)
        response = post_request(request)
        raise_response_error!(response)

        SetupOrderResult.new(
          order_type: order_type.to_s.upcase,
          transaction_id: response.transaction_id.presence,
          order_id: response.order_id.presence)
      end

      def hpb_request_xml(**overrides)
        hpb_request(**overrides).to_xml
      end

      def fetch_bank_public_keys
        responses = order_responses(hpb_request)
        order_data = Btf::Payload.new(responses: responses).order_data
        bank_public_keys = Btf::BankPublicKeys.new(host_id: client.host_id, order_data: order_data)
        bank_public_keys.keys

        receipt_sent = receipt_required?(responses)
        send_receipt!(responses.last.transaction_id, Btf::ReceiptRequest::SUCCESS_CODE) if receipt_sent

        BankPublicKeysResult.new(
          keys: bank_public_keys,
          order_data: order_data,
          receipt_sent: receipt_sent)
      rescue => e
        safely_send_failure_receipt(responses) if defined?(responses)
        raise e
      end

      def key_change(target_key_store:, order_type: "HCS")
        initialisation_request = key_change_request(target_key_store: target_key_store, order_type: order_type)
        initialisation_response = post_request(initialisation_request)
        raise_response_error!(initialisation_response)

        transaction_id = require_response_value!(
          initialisation_response,
          :transaction_id,
          "Missing EBICS HCS initialisation TransactionID")

        transfer_response = post_request(upload_transfer_request(
          transaction_id,
          initialisation_request.payload))
        raise_response_error!(transfer_response)

        KeyChangeResult.new(
          transaction_id: transfer_response.transaction_id.presence || transaction_id,
          order_id: transfer_response.order_id.presence || initialisation_response.order_id)
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
        response = post_request(request)
        raise_response_error!(response)
        validate_initial_segment!(response)
        responses = []
        totals = {
          response_bytes: 0,
          encoded_order_data_bytes: 0,
          encrypted_order_data_bytes: 0
        }
        retain_response!(responses, response, totals)

        while response.segmented? && !response.last_segment?
          raise_invalid_response!("EBICS response exceeds #{MAX_RESPONSE_SEGMENTS} segments") if responses.size >= MAX_RESPONSE_SEGMENTS

          transaction_id = require_response_value!(
            response,
            :transaction_id,
            "Missing EBICS BTD transfer TransactionID")
          next_segment_number = response.next_segment_number
          response = post_request(transfer_request(transaction_id, next_segment_number))
          raise_response_error!(response)
          validate_transfer_segment!(response, transaction_id: transaction_id, segment_number: next_segment_number)
          retain_response!(responses, response, totals)
        end

        responses
      end

      def post_request(request)
        response_from(transport.post(credentials.url, request.to_xml))
      rescue Btf::Transport::HTTPError => e
        raise_response_error!(response_from(e.body)) if e.body.present?

        raise e
      end

      def response_from(response_xml)
        response = Btf::Response.new(client: client, xml: response_xml)
        validate_response_profile!(response)
        verify_response!(response) if response.standard_h005?
        response
      end

      def admin_request(order_type, **overrides)
        Btf::AdminRequest.new(
          client: client,
          order_type: order_type,
          **request_options.merge(overrides))
      end

      def initialization_request(order_type, **overrides)
        Btf::InitializationRequest.new(
          client: client,
          order_type: order_type,
          **setup_request_options.merge(overrides))
      end

      def hpb_request(**overrides)
        Btf::NoPubKeyDigestsRequest.new(
          client: client,
          order_type: "HPB",
          **no_pub_key_digests_request_options.merge(overrides))
      end

      def upload_request(operation, document:, **overrides)
        ensure_btf_upload!(operation)

        Btf::UploadRequest.new(
          client: client,
          operation: operation,
          document: document,
          **request_options.merge(overrides))
      end

      def key_change_request(target_key_store:, order_type:, **overrides)
        Btf::KeyChangeRequest.new(
          client: client,
          target_client: target_key_store,
          order_type: order_type,
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
        return if AdminOrderDataProfile.valid?(order_type, order_data)

        report_unexpected("Unexpected EBICS admin-order response data",
          admin_order_type: order_type.to_s.upcase,
          admin_order_data_profile: "invalid")
        raise AdminOrderDataError, "Unexpected #{order_type.to_s.upcase} response order data"
      end

      def retain_response!(responses, response, totals)
        response_bytes = totals.fetch(:response_bytes) + response.response_bytesize
        if response_bytes > MAX_CUMULATIVE_RESPONSE_BYTES
          raise_invalid_response!("EBICS cumulative response data exceeds #{MAX_CUMULATIVE_RESPONSE_BYTES} bytes")
        end

        encoded_order_data_bytes = totals.fetch(:encoded_order_data_bytes)
        encrypted_order_data_bytes = totals.fetch(:encrypted_order_data_bytes)
        if response.order_data_present?
          encoded_order_data_bytes += response.encoded_order_data_bytes
          if encoded_order_data_bytes > MAX_CUMULATIVE_ENCODED_ORDER_DATA_BYTES
            raise_invalid_response!("EBICS cumulative encoded order data exceeds #{MAX_CUMULATIVE_ENCODED_ORDER_DATA_BYTES} bytes")
          end

          encrypted_order_data_bytes += response.order_data_encrypted.bytesize
          if encrypted_order_data_bytes > MAX_CUMULATIVE_ENCRYPTED_ORDER_DATA_BYTES
            raise_invalid_response!("EBICS cumulative encrypted order data exceeds #{MAX_CUMULATIVE_ENCRYPTED_ORDER_DATA_BYTES} bytes")
          end
        end

        totals[:response_bytes] = response_bytes
        totals[:encoded_order_data_bytes] = encoded_order_data_bytes
        totals[:encrypted_order_data_bytes] = encrypted_order_data_bytes
        responses << response
      end

      def validate_initial_segment!(response)
        return unless response.segmented?

        validate_segment_number!(response, expected: 1)
      end

      def validate_transfer_segment!(response, transaction_id:, segment_number:)
        unless response.transaction_id == transaction_id
          raise_invalid_response!("EBICS response TransactionID is inconsistent")
        end

        validate_segment_number!(response, expected: segment_number)
      end

      def validate_segment_number!(response, expected:)
        segment_number = response.segment_number
        valid_segment = segment_number.to_s.match?(/\A[1-9]\d*\z/) &&
          segment_number.to_i == expected &&
          segment_number.to_i <= MAX_RESPONSE_SEGMENTS
        raise_invalid_response!("EBICS response segment sequence is invalid") unless valid_segment
      end

      def validate_response_profile!(response)
        unless response.h005? && response.schema_valid?
          raise_invalid_response!("Invalid EBICS H005 response")
        end

        return if response.standard_h005? || !verify_signatures

        raise_invalid_response!("Unexpected EBICS key-management response")
      end

      def raise_invalid_response!(message)
        raise TechnicalError.new(InvalidResponseError.new(message))
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

      def setup_order_data_options
        request_options.slice(:certificate_builder, :certificate_issued_at)
      end

      def setup_request_options
        request_options.slice(
          :nonce,
          :timestamp,
          :product_name,
          :language,
          :certificate_builder,
          :certificate_issued_at,
          :order_data)
      end

      def no_pub_key_digests_request_options
        request_options.slice(:nonce, :timestamp, :product_name, :language, :signer)
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
          "response_category" => response.no_download_data? ? "no_data" : response.ok? ? "ok" : "error",
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
        return if response.digest_valid? && response.signature_valid?

        raise TechnicalError.new(VerificationError.new("Invalid EBICS response signature"))
      end

      def ensure_btf_download!(operation)
        return if operation.order_type == "BTD"

        raise UnsupportedOperation,
          "H005/BTF client only supports BTD download operations"
      end

      def ensure_btf_upload!(operation)
        return if operation.order_type == "BTU"

        raise UnsupportedOperation,
          "H005/BTF client only supports BTU upload operations"
      end
    end
  end
end

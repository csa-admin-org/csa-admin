# frozen_string_literal: true

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

      class ResponseError < StandardError
        attr_reader :response

        def initialize(response)
          @response = response
          super([ response.return_code, response.report_text ].compact_blank.join(" "))
        end
      end

      VerificationError = Class.new(StandardError)

      def initialize(credentials, legacy_client: LegacyClient.new(credentials), request_options: {}, transport: Btf::Transport.new, verify_signatures: true)
        @credentials = Credentials.new(credentials)
        @legacy_client = legacy_client
        @request_options = request_options
        @transport = transport
        @verify_signatures = verify_signatures
      end

      def client
        legacy_client.client
      end

      def download(_operation, from:, to:)
        raise UnsupportedOperation,
          "H005/BTF active downloads require ACK-after-processor before they can acknowledge returned data"
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
        raise UnsupportedOperation,
          "H005/BTF uploads are not implemented yet"
      end

      def download_request_xml(operation, from:, to:, **overrides)
        download_request(operation, from: from, to: to, **overrides).to_xml
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
        attr_reader :credentials, :legacy_client, :request_options, :transport, :verify_signatures

        def download_responses(operation, from:, to:)
          ensure_btf_download!(operation)

          [].tap do |responses|
            response = post_request(download_request(operation, from: from, to: to))
            raise_response_error!(response)
            responses << response

            while response.segmented? && !response.last_segment?
              response = post_request(transfer_request(response.transaction_id, response.next_segment_number))
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
    end
  end
end

# frozen_string_literal: true

module Billing
  class EBICS
    class BtfClient
      class ResponseError < StandardError
        attr_reader :response

        def initialize(response)
          @response = response
          super([ response.return_code, response.report_text ].compact_blank.join(" "))
        end
      end

      def initialize(credentials, legacy_client: LegacyClient.new(credentials), request_options: {})
        @credentials = Credentials.new(credentials)
        @legacy_client = legacy_client
        @request_options = request_options
      end

      def client
        legacy_client.client
      end

      def download(operation, from:, to:)
        ensure_btf_download!(operation)

        raise UnsupportedOperation,
          "H005/BTF downloads can build requests but are not connected to transfer/receipt handling yet"
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
        ensure_btf_download!(operation)

        response = Btf::Response.new(client: client, xml: response_xml)
        response_error = ResponseError.new(response)

        raise NoDownloadDataAvailable.new(response_error) if response.no_download_data?
        raise TechnicalError.new(response_error) if response.technical_error?
        raise ClientError.new(response_error) if response.business_error?

        response.files(container: operation.btf["container"])
      end

      private
        attr_reader :credentials, :legacy_client, :request_options

        def ensure_btf_download!(operation)
          return if operation.btf? && operation.order_type == "BTD"

          raise UnsupportedOperation,
            "H005/BTF client only supports BTD download operations"
        end
    end
  end
end

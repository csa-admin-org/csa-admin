# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      class ReceiptRequest
        SUCCESS_CODE = 0
        FAILURE_CODE = 1

        def initialize(client:, transaction_id:, receipt_code: SUCCESS_CODE, signer: nil)
          @client = client
          @transaction_id = transaction_id
          @receipt_code = receipt_code
          @signer = signer || RequestSigner.new(client)
        end

        def to_xml
          signer.sign(unsigned_xml)
        end

        def unsigned_xml
          Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(DownloadRequest::ROOT_ATTRIBUTES) {
              xml.header(authenticate: true) {
                xml.static {
                  xml.HostID client.host_id
                  xml.TransactionID transaction_id
                }
                xml.mutable {
                  xml.TransactionPhase "Receipt"
                }
              }
              DownloadRequest.auth_signature(xml)
              xml.body {
                xml.TransferReceipt(authenticate: true) {
                  xml.ReceiptCode receipt_code
                }
              }
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private
          attr_reader :client, :transaction_id, :receipt_code, :signer
      end
    end
  end
end

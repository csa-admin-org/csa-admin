# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      class ReceiptRequest
        include RequestEnvelope

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
          serialize_xml(Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(root_attributes) {
              transfer_header(xml, transaction_id: transaction_id, phase: "Receipt")
              auth_signature(xml)
              xml.body {
                xml.TransferReceipt(authenticate: true) {
                  xml.ReceiptCode receipt_code
                }
              }
            }
          end)
        end

        private
        attr_reader :client, :transaction_id, :receipt_code, :signer
      end
    end
  end
end

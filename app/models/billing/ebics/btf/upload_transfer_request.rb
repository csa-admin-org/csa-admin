# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      class UploadTransferRequest
        include RequestEnvelope

        def initialize(client:, transaction_id:, payload:, segment_number: 1, last_segment: true, signer: nil)
          @client = client
          @transaction_id = transaction_id
          @payload = payload
          @segment_number = segment_number
          @last_segment = last_segment
          @signer = signer || RequestSigner.new(client)
        end

        def to_xml
          signer.sign(unsigned_xml)
        end

        def unsigned_xml
          serialize_xml(Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(root_attributes) {
              transfer_header(xml, transaction_id: transaction_id, phase: "Transfer", segment_number: segment_number, last_segment: last_segment)
              auth_signature(xml)
              xml.body {
                xml.DataTransfer {
                  xml.OrderData payload.encrypted_order_data
                }
              }
            }
          end)
        end

        private
        attr_reader :client, :transaction_id, :payload, :segment_number, :last_segment, :signer
      end
    end
  end
end

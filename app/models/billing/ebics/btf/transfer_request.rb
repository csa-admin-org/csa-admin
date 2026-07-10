# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      class TransferRequest
        include RequestEnvelope

        def initialize(client:, transaction_id:, segment_number:, signer: nil)
          @client = client
          @transaction_id = transaction_id
          @segment_number = segment_number
          @signer = signer || RequestSigner.new(client)
        end

        def to_xml
          signer.sign(unsigned_xml)
        end

        def unsigned_xml
          serialize_xml(Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(root_attributes) {
              transfer_header(xml, transaction_id: transaction_id, phase: "Transfer", segment_number: segment_number, last_segment: false)
              auth_signature(xml)
              xml.body
            }
          end)
        end

        private

        attr_reader :client, :transaction_id, :segment_number, :signer
      end
    end
  end
end

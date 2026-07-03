# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      class UploadTransferRequest
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
          Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(DownloadRequest::ROOT_ATTRIBUTES) {
              xml.header(authenticate: true) {
                xml.static {
                  xml.HostID client.host_id
                  xml.TransactionID transaction_id
                }
                xml.mutable {
                  xml.TransactionPhase "Transfer"
                  xml.SegmentNumber segment_number, lastSegment: last_segment
                }
              }
              DownloadRequest.auth_signature(xml)
              xml.body {
                xml.DataTransfer {
                  xml.OrderData payload.encrypted_order_data
                }
              }
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private
        attr_reader :client, :transaction_id, :payload, :segment_number, :last_segment, :signer
      end
    end
  end
end

# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      class TransferRequest
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
          Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(root_attributes) {
              xml.header(authenticate: true) {
                xml.static {
                  xml.HostID client.host_id
                  xml.TransactionID transaction_id
                }
                xml.mutable {
                  xml.TransactionPhase "Transfer"
                  xml.SegmentNumber segment_number, lastSegment: false
                }
              }
              auth_signature(xml)
              xml.body
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private
          attr_reader :client, :transaction_id, :segment_number, :signer

          def root_attributes
            DownloadRequest::ROOT_ATTRIBUTES
          end

          def auth_signature(xml)
            DownloadRequest.auth_signature(xml)
          end
      end
    end
  end
end

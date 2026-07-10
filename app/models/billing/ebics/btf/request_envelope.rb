# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      module RequestEnvelope
        XML_SAVE_OPTIONS = Nokogiri::XML::Node::SaveOptions::AS_XML

        private

        def serialize_xml(builder)
          builder.to_xml(save_with: XML_SAVE_OPTIONS, encoding: "utf-8")
        end

        def root_attributes
          DownloadRequest::ROOT_ATTRIBUTES
        end

        def initialisation_header(xml, bank_public_key_digests: true, num_segments: nil, nonce_timestamp: true, transaction_phase: "Initialisation")
          xml.header(authenticate: true) {
            xml.static {
              xml.HostID client.host_id
              if nonce_timestamp
                xml.Nonce nonce
                xml.Timestamp timestamp
              end
              xml.PartnerID client.partner_id
              xml.UserID client.user_id
              xml.Product product_name, Language: language
              yield
              bank_public_key_digests(xml) if bank_public_key_digests
              xml.SecurityMedium "0000"
              xml.NumSegments num_segments if num_segments
            }
            xml.mutable {
              xml.TransactionPhase transaction_phase if transaction_phase
            }
          }
        end

        def transfer_header(xml, transaction_id:, phase:, segment_number: nil, last_segment: nil)
          xml.header(authenticate: true) {
            xml.static {
              xml.HostID client.host_id
              xml.TransactionID transaction_id
            }
            xml.mutable {
              xml.TransactionPhase phase
              xml.SegmentNumber segment_number, lastSegment: last_segment unless segment_number.nil?
            }
          }
        end

        def bank_public_key_digests(xml)
          xml.BankPubKeyDigests {
            xml.Authentication client.bank_x.public_digest,
              Version: "X002",
              Algorithm: DownloadRequest::SHA256_ALGORITHM
            xml.Encryption client.bank_e.public_digest,
              Version: "E002",
              Algorithm: DownloadRequest::SHA256_ALGORITHM
          }
        end

        def auth_signature(xml)
          DownloadRequest.auth_signature(xml)
        end

        def btf_service(xml, btf)
          xml.Service {
            xml.ServiceName btf.fetch("service_name")
            xml.Scope btf.fetch("scope") if btf["scope"].present?
            xml.ServiceOption btf.fetch("service_option") if btf["service_option"].present?
            xml.Container containerType: btf.fetch("container") if btf["container"].present?
            btf_message_name(xml, btf)
          }
        end

        def btf_message_name(xml, btf)
          if btf["version"].present?
            xml.MsgName btf.fetch("message_name"), version: btf.fetch("version")
          else
            xml.MsgName btf.fetch("message_name")
          end
        end
      end
    end
  end
end

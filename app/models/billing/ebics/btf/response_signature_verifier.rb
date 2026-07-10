# frozen_string_literal: true

require "base64"
require "openssl"

module Billing
  class EBICS
    module Btf
      class ResponseSignatureVerifier
        H005_NAMESPACE = Response::H005_NAMESPACE
        XMLDSIG_NAMESPACE = DownloadRequest::XMLDSIG_NAMESPACE
        REFERENCE_URI = "#xpointer(//*[@authenticate='true'])"

        def initialize(client:, doc:)
          @client = client
          @doc = doc
        end

        def valid?
          digest_valid? && signature_valid?
        end

        def digest_valid?
          return false unless profile_valid?

          OpenSSL::Digest::SHA256.digest(authenticated_content) == digest_value
        rescue ArgumentError, OpenSSL::OpenSSLError
          false
        end

        def signature_valid?
          return false unless profile_valid?

          client.bank_x.key.verify(
            OpenSSL::Digest::SHA256.new,
            signature_value,
            signed_info.canonicalize)
        rescue ArgumentError, OpenSSL::OpenSSLError
          false
        end

        private

        attr_reader :client, :doc

        def profile_valid?
          return @profile_valid unless @profile_valid.nil?

          @profile_valid = signed_response_root? && signature_nodes_valid? && algorithms_valid?
        end

        def signed_response_root?
          doc.root&.name == "ebicsResponse" &&
            doc.root.namespace&.href == H005_NAMESPACE &&
            doc.root["Version"] == "H005" &&
            valid_revision?
        end

        def valid_revision?
          doc.root["Revision"].nil? || doc.root["Revision"] == "1"
        end

        def signature_nodes_valid?
          return false unless auth_signature && signed_info && reference && transforms && transform && digest_value_node && signature_value_node
          return false if authenticated_nodes.empty?
          return false unless only_global_node?("//h:AuthSignature", auth_signature, h: H005_NAMESPACE)
          return false unless only_global_node?("//ds:SignedInfo", signed_info, ds: XMLDSIG_NAMESPACE)
          return false unless only_global_node?("//ds:Reference", reference, ds: XMLDSIG_NAMESPACE)
          return false unless only_global_node?("//ds:DigestValue", digest_value_node, ds: XMLDSIG_NAMESPACE)
          return false unless only_global_node?("//ds:SignatureValue", signature_value_node, ds: XMLDSIG_NAMESPACE)

          child_profile?(auth_signature, [ [ H005_NAMESPACE, "AuthSignature" ], [ XMLDSIG_NAMESPACE, "SignedInfo" ], [ XMLDSIG_NAMESPACE, "SignatureValue" ] ], include_self: true) &&
            child_profile?(signed_info, [ [ XMLDSIG_NAMESPACE, "CanonicalizationMethod" ], [ XMLDSIG_NAMESPACE, "SignatureMethod" ], [ XMLDSIG_NAMESPACE, "Reference" ] ]) &&
            child_profile?(reference, [ [ XMLDSIG_NAMESPACE, "Transforms" ], [ XMLDSIG_NAMESPACE, "DigestMethod" ], [ XMLDSIG_NAMESPACE, "DigestValue" ] ]) &&
            child_profile?(transforms, [ [ XMLDSIG_NAMESPACE, "Transform" ] ])
        end

        def algorithms_valid?
          canonicalization_method["Algorithm"] == DownloadRequest::XML_C14N_ALGORITHM &&
            signature_method["Algorithm"] == DownloadRequest::RSA_SHA256_ALGORITHM &&
            reference["URI"] == REFERENCE_URI &&
            transform["Algorithm"] == DownloadRequest::XML_C14N_ALGORITHM &&
            digest_method["Algorithm"] == DownloadRequest::SHA256_ALGORITHM
        end

        def child_profile?(node, expected, include_self: false)
          actual = []
          actual << node_profile(node) if include_self
          actual.concat(node.element_children.map { |child| node_profile(child) })
          actual == expected
        end

        def node_profile(node)
          [ node.namespace&.href, node.name ]
        end

        def only_global_node?(xpath, expected, **namespaces)
          nodes = doc.xpath(xpath, **namespaces)
          nodes.one? && nodes.first == expected
        end

        def auth_signature
          @auth_signature ||= exactly_one(doc.root&.xpath("./h:AuthSignature", h: H005_NAMESPACE))
        end

        def signed_info
          @signed_info ||= exactly_one(auth_signature&.xpath("./ds:SignedInfo", ds: XMLDSIG_NAMESPACE))
        end

        def canonicalization_method
          @canonicalization_method ||= exactly_one(signed_info&.xpath("./ds:CanonicalizationMethod", ds: XMLDSIG_NAMESPACE))
        end

        def signature_method
          @signature_method ||= exactly_one(signed_info&.xpath("./ds:SignatureMethod", ds: XMLDSIG_NAMESPACE))
        end

        def reference
          @reference ||= exactly_one(signed_info&.xpath("./ds:Reference", ds: XMLDSIG_NAMESPACE))
        end

        def transforms
          @transforms ||= exactly_one(reference&.xpath("./ds:Transforms", ds: XMLDSIG_NAMESPACE))
        end

        def transform
          @transform ||= exactly_one(transforms&.xpath("./ds:Transform", ds: XMLDSIG_NAMESPACE))
        end

        def digest_method
          @digest_method ||= exactly_one(reference&.xpath("./ds:DigestMethod", ds: XMLDSIG_NAMESPACE))
        end

        def digest_value_node
          @digest_value_node ||= exactly_one(reference&.xpath("./ds:DigestValue", ds: XMLDSIG_NAMESPACE))
        end

        def signature_value_node
          @signature_value_node ||= exactly_one(auth_signature&.xpath("./ds:SignatureValue", ds: XMLDSIG_NAMESPACE))
        end

        def exactly_one(nodes)
          return unless nodes&.one?

          nodes.first
        end

        def authenticated_content
          authenticated_nodes.map(&:canonicalize).join
        end

        def authenticated_nodes
          @authenticated_nodes ||= doc.xpath("//*[@authenticate='true']")
        end

        def digest_value
          decode_xml_base64(digest_value_node)
        end

        def signature_value
          decode_xml_base64(signature_value_node)
        end

        def decode_xml_base64(node)
          Base64.strict_decode64(node.content.to_s.gsub(/\s+/, ""))
        end
      end
    end
  end
end

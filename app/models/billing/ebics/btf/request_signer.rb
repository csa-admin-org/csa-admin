# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"

module Billing
  class EBICS
    module Btf
      class RequestSigner
        def initialize(client)
          @client = client
        end

        def sign(xml)
          digest!(doc = Nokogiri::XML(xml))
          sign!(doc)
          doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private

        attr_reader :client

        def digest!(doc)
          digest_node(doc).content = Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(authenticated_content(doc)))
        end

        def sign!(doc)
          signature_value_node(doc).content = Base64.strict_encode64(
            client.x.key.sign(OpenSSL::Digest::SHA256.new, signed_info_node(doc).canonicalize))
        end

        def authenticated_content(doc)
          doc.xpath("//*[@authenticate='true']").map(&:canonicalize).join
        end

        def digest_node(doc)
          doc.at_xpath("//ds:DigestValue", ds: DownloadRequest::XMLDSIG_NAMESPACE)
        end

        def signed_info_node(doc)
          doc.at_xpath("//ds:SignedInfo", ds: DownloadRequest::XMLDSIG_NAMESPACE)
        end

        def signature_value_node(doc)
          doc.at_xpath("//ds:SignatureValue", ds: DownloadRequest::XMLDSIG_NAMESPACE)
        end
      end
    end
  end
end

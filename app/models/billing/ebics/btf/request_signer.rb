# frozen_string_literal: true

require "epics"
require "nokogiri"

module Billing
  class EBICS
    module Btf
      class RequestSigner
        def initialize(client)
          @client = client
        end

        def sign(xml)
          signer = ::Epics::Signer.new(client, xml)
          signer.digest!
          signer.sign!
          signer.doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private
          attr_reader :client
      end
    end
  end
end

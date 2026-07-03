# frozen_string_literal: true

require "base64"
require "openssl"

module Billing
  class EBICS
    class Key
      attr_reader :key

      def initialize(key)
        @key = key.is_a?(OpenSSL::PKey::RSA) ? key : OpenSSL::PKey::RSA.new(key)
      end

      def public_digest
        values = [ key.e, key.n ].map { |value| value.to_s(16).sub(/\A0+/, "").downcase }
        Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(values.join(" ")))
      end

      def sign(digest)
        Base64.strict_encode64(key.sign_pss(
          "SHA256",
          digest,
          salt_length: :digest,
          mgf1_hash: "SHA256"))
      end
    end
  end
end

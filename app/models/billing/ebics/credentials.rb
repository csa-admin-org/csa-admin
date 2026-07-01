# frozen_string_literal: true

module Billing
  class EBICS
    class Credentials
      attr_reader :attributes

      def initialize(attributes = {})
        @attributes = (attributes || {}).to_h.deep_stringify_keys
      end

      def fetch(key)
        attributes.fetch(key.to_s)
      end

      def keys = fetch(:keys)
      def secret = fetch(:secret)
      def url = fetch(:url)
      def host_id = fetch(:host_id)
      def participant_id = fetch(:participant_id)
      def client_id = fetch(:client_id)

      def schema_version
        attributes["schema_version"]
      end

      def epics_client_args
        [ keys, secret, url, host_id, participant_id, client_id ]
      end

      def epics_setup_args(keysize)
        [ secret, url, host_id, participant_id, client_id, keysize ]
      end

      def to_h
        attributes.dup
      end
    end
  end
end

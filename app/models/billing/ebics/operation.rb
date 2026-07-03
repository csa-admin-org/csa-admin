# frozen_string_literal: true

module Billing
  class EBICS
    class Operation
      attr_reader :order_type, :btf

      def self.btf(attributes)
        new(attributes.to_h.deep_stringify_keys)
      end

      def initialize(attributes)
        @btf = attributes.to_h.deep_stringify_keys
        @order_type = btf.fetch("order_type")
      end
    end
  end
end

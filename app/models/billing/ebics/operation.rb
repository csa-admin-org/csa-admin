# frozen_string_literal: true

module Billing
  class EBICS
    class Operation
      attr_reader :mode, :order_type, :btf

      def self.order_type(order_type)
        new("order_type", order_type: order_type)
      end

      def self.btf(attributes)
        attributes = attributes.to_h.deep_stringify_keys
        new("btf", order_type: attributes.fetch("order_type"), btf: attributes)
      end

      def initialize(mode, order_type:, btf: nil)
        @mode = mode.to_s
        @order_type = order_type.to_s
        @btf = btf&.deep_stringify_keys
      end

      def order_type?
        mode == "order_type"
      end

      def btf?
        mode == "btf"
      end

      def method_name
        order_type.to_sym
      end
    end
  end
end

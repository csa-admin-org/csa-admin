# frozen_string_literal: true

module Billing
  class EBICSMock
    def initialize(credentials = {})
      @credentials = credentials.symbolize_keys
    end

    def payments_data
      []
    end

    def sepa_direct_debit_upload(document)
      # transaction_id, order_id
      [ "1234", "N042" ]
    end
  end
end

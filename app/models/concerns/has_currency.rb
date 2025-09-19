# frozen_string_literal: true

module HasCurrency
  extend ActiveSupport::Concern

  included do
    attribute :currency_code, :string, default: -> { Current.org.currency_code }

    validates :currency_code, presence: true, inclusion: { in: Organization::CURRENCIES }
  end
end
